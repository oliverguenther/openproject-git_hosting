require 'fileutils'

module OpenProject::Revisions::Git
  module Patches
    module SettingPatch
      def self.included(base)
        base.class_eval do
          unloadable

          include InstanceMethods

          before_save :validate_settings
          after_commit :restore_revisions_git_values
        end
      end

      module InstanceMethods
        private

        @@old_valuehash = Setting.plugin_openproject_revisions_git.clone
        @@resync_projects = false
        @@resync_ssh_keys = false
        @@delete_trash_repo = []

        def validate_settings
          # Only validate settings for our plugin
          return unless name == 'plugin_openproject_revisions_git'

          valuehash = value

          # Validate partials
          validate_server_names valuehash
          validate_gitolite_settings valuehash
          validate_git_config valuehash

          # Prepare any resync after sync
          prepare_resyncs valuehash

          # Save back results
          self.value = valuehash
        end

        def validate_server_names(valuehash)
          # Server domain should not include any path components. Also, ports should be numeric.
          [:https_server_domain, :ssh_server_domain, :http_server_domain].each do |setting|
            if valuehash[setting] && !valuehash[setting].empty?
              valuehash[setting] = valuehash[setting].lstrip.rstrip.split('/').first
            else
              valuehash[setting] = @@old_valuehash[setting]
            end
          end
        end

        def validate_gitolite_settings(valuehash)
          # Normalize paths, should be relative and end in '/'
          valuehash[:gitolite_global_storage_path] = File.join(valuehash[:gitolite_global_storage_path], '')

          # Validate ssh port > 0 and < 65537 (and exclude non-numbers)
          port = valuehash[:gitolite_server_port]
          if !port.to_i.between?(1, 65537)
            valuehash[:gitolite_server_port] = @@old_valuehash[:gitolite_server_port]
          end
        end

        def validate_git_config(valuehash)
          # Validate git author address
          if valuehash[:git_config_email].blank?
            valuehash[:git_config_email] = Setting.mail_from.to_s.strip.downcase
          elsif !/^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i.match(valuehash[:git_config_email])
            valuehash[:git_config_email] = @@old_valuehash[:git_config_email]
          end
        end

        def prepare_resyncs(valuehash)
          ## Rest force update requests
          @@resync_projects = valuehash[:gitolite_resync_all_projects] == 'true'
          valuehash[:gitolite_resync_all_projects] = false
        end

        def restore_revisions_git_values
          # Only perform after-actions on settings for our plugin
          if name == 'plugin_openproject_revisions_git'
            valuehash = value

            ## A resync has been asked within the interface, update all projects in force mode
            if @@resync_projects == true
              resync_projects
              @@resync_projects = false
            end

            @@old_valuehash = valuehash.clone
          end
        end

        def resync_projects
          # Need to update everyone!
          projects = Project.active.includes(:repository).all
          if projects.length > 0
            OpenProject::Revisions::Git::GitoliteWrapper.logger.info(
              "Forced resync of all projects (#{projects.length})..."
            )
            OpenProject::Revisions::Git::GitoliteWrapper.update(:update_all_projects, projects.length)
          end
        end
      end
    end
  end
end

Setting.send(:include, OpenProject::Revisions::Git::Patches::SettingPatch)
