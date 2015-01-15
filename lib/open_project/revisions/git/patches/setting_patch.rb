require 'fileutils'

module OpenProject::Revisions::Git
  module Patches
    module SettingPatch

      def self.included(base)
        base.class_eval do
          unloadable

          include InstanceMethods

          before_save  :save_revisions_git_values
          after_commit :restore_revisions_git_values
        end
      end

      module InstanceMethods

        private

        @@old_valuehash = ((Setting.plugin_openproject_revisions_git).clone rescue {})
        @@resync_projects = false
        @@resync_ssh_keys = false
        @@delete_trash_repo = []

        def save_revisions_git_values
          # Only validate settings for our plugin
          if self.name == 'plugin_openproject_revisions_git'
            valuehash = self.value

            # Server domain should not include any path components. Also, ports should be numeric.
            [ :ssh_server_domain, :http_server_domain ].each do |setting|
              if valuehash[setting]
                if valuehash[setting] != ''
                  normalizedServer = valuehash[setting].lstrip.rstrip.split('/').first
                  if (!normalizedServer.match(/^[a-zA-Z0-9\-]+(\.[a-zA-Z0-9\-]+)*(:\d+)?$/))
                    valuehash[setting] = @@old_valuehash[setting]
                  else
                    valuehash[setting] = normalizedServer
                  end
                else
                  valuehash[setting] = @@old_valuehash[setting]
                end
              end
            end


            # HTTPS server should not include any path components. Also, ports should be numeric.
            if valuehash[:https_server_domain]
              if valuehash[:https_server_domain] != ''
                normalizedServer = valuehash[:https_server_domain].lstrip.rstrip.split('/').first
                if (!normalizedServer.match(/^[a-zA-Z0-9\-]+(\.[a-zA-Z0-9\-]+)*(:\d+)?$/))
                  valuehash[:https_server_domain] = @@old_valuehash[:https_server_domain]
                else
                  valuehash[:https_server_domain] = normalizedServer
                end
              end
            end


            # Normalize paths, should be relative and end in '/'
            if valuehash[:gitolite_global_storage_path]
              valuehash[:gitolite_global_storage_path] = File.join(valuehash[:gitolite_global_storage_path], "")
            end


            # Validate ssh port > 0 and < 65537 (and exclude non-numbers)
            if valuehash[:gitolite_server_port]
              if valuehash[:gitolite_server_port].to_i > 0 and valuehash[:gitolite_server_port].to_i < 65537
                valuehash[:gitolite_server_port] = "#{valuehash[:gitolite_server_port].to_i}"
              else
                valuehash[:gitolite_server_port] = @@old_valuehash[:gitolite_server_port]
              end
            end


            # Validate git author address
            if valuehash[:git_config_email].blank?
              valuehash[:git_config_email] = Setting.mail_from.to_s.strip.downcase
            else
              if !/^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i.match(valuehash[:git_config_email])
                valuehash[:git_config_email] = @@old_valuehash[:git_config_email]
              end
            end


            ## This a force update
            if valuehash[:gitolite_resync_all_projects] == 'true'
              @@resync_projects = true
              valuehash[:gitolite_resync_all_projects] = false
            end


            ## This a force update
            if valuehash[:gitolite_resync_all_ssh_keys] == 'true'
              @@resync_ssh_keys = true
              valuehash[:gitolite_resync_all_ssh_keys] = false
            end


            if valuehash[:all_projects_use_git] == 'false'
              valuehash[:init_repositories_on_create] = 'false'
            end


            # Save back results
            self.value = valuehash
          end
        end


        def restore_revisions_git_values
          # Only perform after-actions on settings for our plugin
          if self.name == 'plugin_openproject_revisions_git'
            valuehash = self.value

            ## A resync has been asked within the interface, update all projects in force mode
            if @@resync_projects == true
              # Need to update everyone!
              projects = Project.active.includes(:repositories).all
              if projects.length > 0
                OpenProject::Revisions::Git::GitoliteWrapper.logger.info("Forced resync of all projects (#{projects.length})...")
                OpenProject::Revisions::Git::GitoliteWrapper.update(:update_all_projects, projects.length)
              end

              @@resync_projects = false
            end


            ## A resync has been asked within the interface, update all projects in force mode
            if @@resync_ssh_keys == true
              # Need to update everyone!
              users = User.all
              if users.length > 0
                OpenProject::Revisions::Git::GitoliteWrapper.logger.info("Forced resync of all ssh keys (#{users.length})...")
                OpenProject::Revisions::Git::GitoliteWrapper.update(:update_all_ssh_keys_forced, users.length)
              end

              @@resync_ssh_keys = false
            end

            @@old_valuehash = valuehash.clone
          end
        end

      end

    end
  end
end

Setting.send(:include, OpenProject::Revisions::Git::Patches::SettingPatch)
