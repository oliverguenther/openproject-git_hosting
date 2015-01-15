require 'pathname'
module OpenProject::Revisions::Git::GitoliteWrapper
  module RepositoriesHelper

    def handle_repository_add(repository, opts = {})
      repo_name = repository.gitolite_repository_name
      repo_path = repository.git_path
      project   = repository.project

      if @gitolite_config.repos[repo_name]
        logger.warn("#{@action} : repository '#{repo_name}' already exists in Gitolite, removing first")
        @gitolite_config.rm_repo(repo_name)
      end

      # Create new repo object
      repo_conf = Gitolite::Config::Repo.new(repo_name)
      set_repo_config_keys(repo_conf, repository)

      @gitolite_config.add_repo(repo_conf)
      repo_conf.permissions = [build_permissions(repository)]
    end


    #
    # Sets the git config-keys for the given repo configuration
    #
    def set_repo_config_keys(repo_conf, repository)
      # Set post-receive hook params
      repo_conf.set_git_config("openproject.githosting.projectid", repository.project.identifier.to_s)
      repo_conf.set_git_config("http.uploadpack", (User.anonymous.allowed_to?(:view_changesets, repository.project) ||
        repository.extra[:git_http]))

      # Set Git config keys
      repository.repository_git_config_keys.each do |config_entry|
        repo_conf.set_git_config(config_entry.key, config_entry.value)
      end
    end

    # Delete the reposistory from gitolite-admin (and commit)
    # and yield (e.g., for deletion / moving to trash before commit)
    #
    def handle_repository_delete(repos)
      @admin.transaction do
        repos.each do |repo|
          if @gitolite_config.repos[repo[:name]]

            # Delete from in-memory gitolite
            @gitolite_config.rm_repo(repo[:name])

            # Allow post-processing of removed repo
            yield repo

            # Commit changes
            gitolite_admin_repo_commit(repo[:name])
          else
            logger.warn("#{@action} : '#{repo[:name]}' does not exist in Gitolite")
          end
        end
      end
    end


    # Move a list of git repositories to their new location
    #
    # The old repository location is expected to be available from its url.
    # Upon moving the project (e.g., to a subproject),
    # the repository's url will still reflect its old location.
    def handle_repositories_move(repos)

      # We'll need the repository root directory.
      gitolite_repos_root = OpenProject::Revisions::Git::GitoliteWrapper.gitolite_global_storage_path
      repos.each do |repo|

        # Old name is the <path> section of above, thus extract it from url.
        # But remove the '.git' part.
        old_repository_name = File.basename(repo.url, '.git')
        old_repository_path = File.join(gitolite_repos_root, repo.url)

        # Actually move the repository
        do_move_repository(repo, old_repository_path, old_repository_name)

        gitolite_admin_repo_commit("#{@action} : #{repo.project.identifier}")
      end
    end


    # Move a repository in gitolite-admin from its old entry to a new one
    #
    # This involves the following steps:
    # 1. Remove the old entry (+old_name+)
    # 2. Move the physical repository on filesystem.
    # 3. Add the repository using +repo.gitolite_repository_name+
    #
    def do_move_repository(repo, old_path, old_name)

      new_name  = repo.gitolite_repository_name
      new_path  = repo.absolute_repository_path

      logger.info("#{@action} : Moving '#{old_name}' -> '#{new_name}'")
      logger.debug("-- On filesystem, this means '#{old_path}' -> '#{new_path}'")

      # Remove old config entry
      old_repo_conf = @gitolite_config.rm_repo(old_name)

      # Move the repo on filesystem
      move_physical_repo(old_path, new_path)

      # Add the repo as new
      handle_repository_add(repo)

    end

    def move_physical_repo(old_path, new_path)

      if old_path == new_path
        logger.warn("#{@action} : old repository and new repository are identical '#{old_path}' .. why move?")
        return
      end

      # If the new path exists, some old project wasn't correctly cleaned.
      if File.directory?(new_path)
        logger.warn("#{@action} : New location '#{new_path}' was non-empty. Cleaning first.")
        clean_repo_dir(new_path)
      end

      # Old repository has never been created by gitolite
      # => No need to move anything on the disk
      if !File.directory?(old_path)
        logger.info("#{@action} : Old location '#{old_path}' was never created. Skipping disk movement.")
        return
      end

      # Otherwise, move the old repo
      FileUtils.mv(old_path, new_path, force: true)

      # Clean up the old path
      clean_repo_dir(old_path)
    end

    # Removes the repository path and all parent repositories that are empty
    #
    # (i.e., if moving foo/bar/repo.git to foo/repo.git, foo/bar remains and is possibly abandoned)
    # This moves up from the lowermost point, and deletes all empty directories.
    def clean_repo_dir(path)
      parent = Pathname.new(path).parent
      repo_root = Pathname.new(OpenProject::Revisions::Git::GitoliteWrapper.gitolite_global_storage_path)

      # Delete the repository project itself.
      FileUtils.rm_rf(path)

      loop do

        # Stop deletion upon finding a non-empty parent repository
        break unless parent.children(false).empty?

        # Stop if we're in the project root
        break if parent == repo_root

        logger.info("#{@action} : Cleaning repository directory #{parent} ... ")
        FileUtils.rmdir(parent)
        parent = parent.parent
      end
    end

    # Builds the set of permissions for all
    # users and deploy keys of the repository
    #
    def build_permissions(repository)
      users   = repository.project.member_principals.map(&:user).compact.uniq
      project = repository.project

      rewind = []
      write  = []
      read   = []

      rewind_users = users.select{|user| user.allowed_to?(:manage_repository, project)}
      write_users  = users.select{|user| user.allowed_to?(:commit_access, project)} - rewind_users
      read_users   = users.select{|user| user.allowed_to?(:view_changesets, project)} - rewind_users - write_users

      if project.active?
        rewind = rewind_users.map{|user| user.gitolite_identifier}
        write  = write_users.map{|user| user.gitolite_identifier}
        read   = read_users.map{|user| user.gitolite_identifier}

        read << "DUMMY_REDMINE_KEY" if read.empty? && write.empty? && rewind.empty?
        read << "gitweb" if User.anonymous.allowed_to?(:browse_repository, project) && repository.extra[:git_http] != 0
        read << "daemon" if User.anonymous.allowed_to?(:view_changesets, project) && repository.extra[:git_daemon]
      else
        all_read = rewind_users + write_users + read_users
        read     = all_read.map{|user| user.gitolite_identifier}
        read << "REDMINE_CLOSED_PROJECT" if read.empty?
      end

      permissions = {}
      permissions["RW+"] = {"" => rewind.uniq.sort} unless rewind.empty?
      permissions["RW"] = {"" => write.uniq.sort} unless write.empty?
      permissions["R"] = {"" => read.uniq.sort} unless read.empty?

      permissions
    end
  end
end
