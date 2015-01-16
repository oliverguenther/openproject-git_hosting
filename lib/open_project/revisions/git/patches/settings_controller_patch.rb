module OpenProject::Revisions::Git
  module Patches
    module SettingsControllerPatch
      def self.included(base)
        base.class_eval do
          unloadable

          helper :revisions_git
        end
      end
    end
  end
end

SettingsController.send(:include, OpenProject::Revisions::Git::Patches::SettingsControllerPatch)
