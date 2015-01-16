require 'socket'
module OpenProject::Revisions::Git
  GITHUB_ISSUE = 'https://github.com/oliverguenther/openproject-revisions_git/issues'

  class Engine < ::Rails::Engine
    engine_name :openproject_revisions_git

    def self.default_hostname
      Socket.gethostname || 'localhost'
    rescue
      nil
    end

    def self.settings
      {
        partial: 'settings/openproject_revisions_git',
        default:
        {
          # Gitolite SSH Config
          gitolite_user: 'git',
          gitolite_server_port: '22',
          gitolite_ssh_private_key: File.join(Dir.home, '.ssh', 'id_rsa').to_s,
          gitolite_ssh_public_key: File.join(Dir.home, '.ssh', 'id_rsa.pub').to_s,

          # Gitolite Storage Config
          # deprecated
          gitolite_global_storage_dir: 'repositories',
          # Full path
          gitolite_global_storage_path: '/home/git/repositories',

          # Gitolite Config File
          gitolite_admin_dir: File.join(Dir.home, 'gitolite-admin'),

          # Gitolite Global Config
          gitolite_scripts_dir: File.join(Dir.home, 'bin'),
          gitolite_timeout: 10,
          gitolite_log_level: 'info',
          gitolite_log_split: false,
          git_config_username: 'OpenProject Revisions(Git)',
          git_config_email: 'openproject@localhost',

          # Gitolite Access Config
          ssh_server_domain: default_hostname,
          https_server_domain: default_hostname,
          gitolite_daemon_by_default: false,
          gitolite_http_by_default: 1,

          # Redmine Config
          init_repositories_on_create: false,

          # Delayed jobs
          use_delayed_jobs: false,
        }
      }
    end

    include OpenProject::Plugins::ActsAsOpEngine

    register(
      'openproject-revisions_git',
      author_url: 'https://github.com/oliverguenther/openproject_revisions_git',
      requires_openproject: '>= 3.0.0',
      settings: settings
    ) do
      project_module :repository do
        permission :create_repository_git_config_keys, repository_git_config_keys: :create
        permission :view_repository_git_config_keys, repository_git_config_keys: :index
        permission :edit_repository_git_config_keys, repository_git_config_keys: :edit

        permission :create_gitolite_ssh_key, my: :account
        permission :download_git_revision, download_git_revision: :index
      end

      # Public Keys under user account
      menu(
        :my_menu,
        :public_keys,
        { controller: 'my_public_keys', action: 'index' },
        html: { class: 'icon2 icon-locked-folder' },
        caption: :label_public_keys
      )
    end

    config.to_prepare do
      # act_as_op_engine doesn't like the hierarchical plugin/engine name :)
      [
        :user, :setting, :settings_controller,
        :users_controller, :my_controller, :repositories_helper, :users_helper,
        :repository_git
      ].each do |sym|
        require_dependency "open_project/revisions/git/patches/#{sym}_patch"
      end
    end

    initializer 'revisons_git.precompile_assets' do
      Rails.application.config.assets.precompile += %w(revisions_git/revisions_git.css)
    end

    initializer 'revisions_git.hooks' do
      require 'open_project/revisions/git/hooks'
      require 'open_project/revisions/git/hooks/gitolite_updater'
      OpenProject::Revisions::ProxiedRepositoryHook.delegate(Hooks::GitoliteUpdaterHook)
    end
  end
end
