module OpenProject::Revisions::Git::GitoliteWrapper
  class Repositories < Admin
    include OpenProject::Revisions::Git::GitoliteWrapper::RepositoriesHelper

    def add_repository
      repository = @object_id
      @admin.transaction do
        handle_repository_add(repository)

        gitolite_admin_repo_commit("#{repository.gitolite_repository_name}")
        logger.info { "#{@action} : let Gitolite create empty repository '#{repository.git_path}'" }
      end
    end

    def update_repository
      # We override the repository in gitolite anyway
      add_repository
    end

    # Remove the given repositories from gitolite-admin
    # Does NOT remove the repository from filesystem.
    def remove_repositories
      handle_repository_delete(@object_id)
    end

    # Delete the given repositories.
    #
    # As the project/repo model may be deleted already,
    # receives an array of repo name and path.
    #
    # Performs two steps
    # 1. Delete the reposistory from gitolite-admin (and commit)
    # 2. Delete the physical repository
    # (and all empty parent directories within the repository storage)
    def delete_repositories
      handle_repository_delete(@object_id) do |repo|
        # Delete all empty parent directories
        # From the lowermost repository
        clean_repo_dir(repo[:path])
      end
    end
  end
end
