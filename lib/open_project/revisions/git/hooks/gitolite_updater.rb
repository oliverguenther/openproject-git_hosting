module OpenProject::Revisions::Git::Hooks

  class GitoliteUpdaterHook

    def accepts?(method, context)
      repository = context[:repository] || context[:project].repository
      return repository.is_a?(Repository::Git)
    end

    def membership_updated(context)

      project = context[:project]
      OpenProject::Revisions::Git::GitoliteWrapper.logger.info("Membership changes on project '#{project.identifier}', update!")
      OpenProject::Revisions::Git::GitoliteWrapper.update(:update_repository, project.repository)
    end

    def project_updated(context)
      project = context[:project]

      if project.repository.url != project.repository.git_path ||
         project.repository.url != project.repository.root_url

        OpenProject::Revisions::Git::GitoliteWrapper.logger.info("Move repositories of project : '#{project}'")
        OpenProject::Revisions::Git::GitoliteWrapper.update(:move_repositories, project.id)
      else
        # Adjust daemon status
        # Go through all gitolite repos and disable Git daemon if necessary
        if project.repository.extra[:git_daemon] && !project.is_public
          project.repository.extra[:git_daemon] = false
          project.repository.extra.save
        end
        OpenProject::Revisions::Git::GitoliteWrapper.logger.info("Set Git daemon for repositories of project : '#{project}'" )
        OpenProject::Revisions::Git::GitoliteWrapper.update(:update_repository, project.repository)
      end
    end

    def project_deletion_imminent(context)
      project = context[:project]

      # Remember all projects with git repositories we have to delete later on.
      # Reverse the list to remove the lowermost repo first.
      destroy_repos = flatten_project_git_repos(project).reverse

      if context[:confirm]
        OpenProject::Revisions::Git::GitoliteWrapper.update(:delete_repositories, destroy_repos)
      end
    end

    def repository_edited(context)
      repository = context[:repository]
      OpenProject::Revisions::Git::GitoliteWrapper.logger.info("User '#{User.current.login}' created a \
        new repository '#{repository.gitolite_repository_name}'")

      OpenProject::Revisions::Git::GitoliteWrapper.update(:add_repository, repository)
    end

    def repository_destroyed(context)
      repository = context[:repository]
      OpenProject::Revisions::Git::GitoliteWrapper.logger.info("User '#{User.current.login}' has removed \
        repository '#{repository.gitolite_repository_name}'")

      repository_data = {
        name: repository.gitolite_repository_name,
        path: repository.git_path
      }
      OpenProject::Revisions::Git::GitoliteWrapper.update(:delete_repositories, [repository_data])
    end

    private

    # Given a list of projects, returns a list of Git repos
    # of all subprojects with two keys:
    # name, path of the repository
    def flatten_project_git_repos(project)
      projects = project.self_and_descendants.uniq
        .select{|p| p.repository.is_a?(Repository::Git)}

      projects.map do |project|
        { name: project.repository.gitolite_repository_name,
          path: project.repository.git_path }
      end
    end
  end
end