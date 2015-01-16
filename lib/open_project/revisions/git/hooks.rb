require 'digest/md5'

module OpenProject::Revisions::Git::Hooks
  class RoleUpdater < Redmine::Hook::Listener
    def roles_changed(context)
      message = context[:message]
      projects = Project.active.includes(:repository).all
      if projects.length > 0
        OpenProject::Revisions::Git::GitoliteWrapper.logger.info("Role has been #{message}, resync all projects...")
        OpenProject::Revisions::Git::GitoliteWrapper.update(:update_all_projects, projects.length)
      end
    end
  end

  class AttributeHook < Redmine::Hook::ViewListener
    render_on :view_create_project_form_attributes, partial: 'projects/form/attributes/git_project'
  end
end
