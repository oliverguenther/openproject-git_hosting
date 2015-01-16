module RevisionsGitHelper
  include Redmine::I18n

  def user_allowed_to(permission, project)
    if project.active?
      return User.current.allowed_to?(permission, project)
    else
      return User.current.allowed_to?(permission, nil, global: true)
    end
  end
end
