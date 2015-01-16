require_dependency 'repository/git'

module OpenProject::Revisions::Git
  module Patches
    module RepositoryGitPatch
      def self.included(base)
        base.class_eval do
          unloadable

          include InstanceMethods
          extend ClassMethods

          has_one :extra, foreign_key: 'repository_id', class_name: 'RepositoryGitExtra', dependent: :destroy
          accepts_nested_attributes_for :extra

          has_many :repository_git_config_keys, dependent: :destroy, foreign_key: 'repository_id'

          before_validation :set_git_urls
        end
      end

      module ClassMethods
        # Parse a path of the form <proj1>/<proj2>/<proj3>/<projekt>.git and return the specified
        # project identifier.
        #
        # Example: project1/subproject1/myproject.git => 'myproject'

        def find_by_path(path)
          identifier = File.basename(path, '.*')
          if (project = Project.find_by_identifier(identifier))
            project.repository
          end
        end
      end

      module InstanceMethods
        # Returns the hierarchical repository path
        # e.g., "foo/bar.git"
        def git_path
          [gitolite_repository_name, '.git'].join
        end

        # Returns the repository path to locate gitolite
        # (relative from +gitolite_users+ $HOME)
        #
        # e.g., Project Foo, Subproject Bar => 'repositories/foo/bar.git'
        def absolute_repository_path
          File.join(
            OpenProject::Revisions::Git::GitoliteWrapper.gitolite_global_storage_path,
            git_path
          )
        end

        # Returns the repository name
        #
        # e.g., Project Foo, Subproject Bar => 'foo/bar'
        def gitolite_repository_name
          if (parent_path = get_full_parent_path).empty?
            project.identifier
          else
            File.join(parent_path, project.identifier)
          end
        end

        def http_user_login
          User.current.anonymous? ? '' : "#{User.current.login}@"
        end

        def ssh_url
          [
            'ssh://',
            Setting.plugin_openproject_revisions_git[:gitolite_user],
            '@',
            Setting.plugin_openproject_revisions_git[:ssh_server_domain],
            '/',
            git_path
          ].join
        end

        def ssh_clone_command
          "git clone #{ssh_url}"
        end

        def git_url
          "git://#{Setting.plugin_openproject_revisions_git[:ssh_server_domain]}/#{git_path}"
        end

        def git_clone_command
          "git clone #{git_url}"
        end

        def https_url
          [
            'https://', http_user_login,
            Setting.plugin_openproject_revisions_git[:https_server_domain],
            '/',
            http_access_path
          ].join
        end

        def available_urls
          hash = available_url_hash

          delete hash[:ssh] if User.current.anonymous?
          delete hash[:https] unless extra[:git_http]
          delete hash[:git] unless extra[:git_daemon]

          hash
        end

        def get_full_parent_path
          parent_parts = []
          p = project
          while p.parent
            parent_id = p.parent.identifier.to_s
            parent_parts.unshift(parent_id)
            p = p.parent
          end

          File.join(*parent_parts)
        end

        private

        def available_url_hash
          commiter = User.current.allowed_to?(:commit_access, project)

          {
            ssh: {
              url: ssh_url,
              command: ssh_clone_command,
              commiter: commiter
            },
            https: {
              url: https_url,
              command: https_url,
              commiter: commiter
            },
            git: {
              url: git_url,
              command: git_clone_command,
              commiter: false,
            }
          }
        end

        # Set up git urls for new repositories
        def set_git_urls
          self.url = git_path if url.blank?
          self.root_url = url if root_url.blank?
        end
      end
    end
  end
end
Repository::Git.send(:include, OpenProject::Revisions::Git::Patches::RepositoryGitPatch)
