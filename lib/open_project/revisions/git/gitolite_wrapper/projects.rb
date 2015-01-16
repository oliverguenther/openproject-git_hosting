module OpenProject::Revisions::Git::GitoliteWrapper
  class Projects < Admin
    include RepositoriesHelper

    def update_projects
      perform_update([@object_id])
    end

    def update_all_projects
      projects = Project.active.includes(:repository).all
      perform_update(projects)
    end

    def move_repositories
      projects = Project.find_by_id(@object_id).self_and_descendants

      # Only take projects that have Git repos.
      git_projects = projects.map { |p| p.repository if p.repository.is_a?(Repository::Git) }.compact
      return if git_projects.empty?

      @admin.transaction do
        handle_repositories_move(git_projects)
      end
    end

    def move_repositories_tree
      projects = Project.active.includes(:repository).all.select { |x| x.parent_id.nil? }

      @admin.transaction do
        projects.each do |project|
          # Only take projects that have Git repos.
          git_projects =
            project
            .self_and_descendants
            .map { |p| p.repository if p.repository.is_a?(Repository::Git) }.compact

          next if git_projects.empty?

          handle_repositories_move(git_projects)
        end
      end
    end

    private

    # Updates a set of projects by re-adding
    # them to gitolite.
    #
    def perform_update(projects)
      @admin.transaction do
        projects.each do |project|
          next unless project.repository.is_a?(Repository::Git)

          handle_repository_add(project.repository)
          gitolite_admin_repo_commit("#{project.identifier}")
        end
      end
    end
  end
end
