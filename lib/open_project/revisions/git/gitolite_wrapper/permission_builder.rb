module OpenProject::Revisions::Git::GitoliteWrapper
  class PermissionBuilder
    def initialize(repository)
      @repository = repository
      @project = repository.project

      # Read permissions and eligbile users
      # from OpenProject project members
      prepare
    end

    # Select eligible users
    def prepare
      @users   = @project.member_principals.map(&:user).compact.uniq
      build_op_permissions
    end

    def build_op_permissions
      @rewind_users = @users.select { |user| user.allowed_to?(:manage_repository, @project) }

      @write_users =
        @users.select { |user| user.allowed_to?(:commit_access, @project) } -
        @rewind_users

      @read_users =
        @users.select { |user| user.allowed_to?(:view_changesets, @project) } -
        @rewind_users -
        @write_users

      @rewind = []
      @write  = []
      @read   = []
    end

    def get_identifier(set)
      set.map(&:gitolite_identifier)
    end

    def gitweb_enabled?
      User.anonymous.allowed_to?(:browse_repository, @project) && @repository.extra[:git_http] != 0
    end

    def git_daemon_enabled?
      User.anonymous.allowed_to?(:view_changesets, @project) && repository.extra[:git_daemon]
    end

    # Builds the set of permissions for all
    # users and deploy keys of the repository
    #
    def build_permissions!
      if @project.active?
        @rewind = get_identifier(@rewind_users)
        @write  = get_identifier(@write_users)
        @read   = get_identifier(@read_users)
        active_project_gitolite_access
      else
        all_read = @rewind_users + @write_users + @read_users
        @read     = get_identifier(all_read)
        @read << 'REDMINE_CLOSED_PROJECT' if @read.empty?
      end

      convert_to_gitolite_format
    end

    def active_project_gitolite_access
      @read << 'DUMMY_REDMINE_KEY' if @read.empty? && @write.empty? && @rewind.empty?
      @read << 'gitweb' if gitweb_enabled?
      @read << 'daemon' if git_daemon_enabled?
    end

    # Turn the internal hash into the gitolite
    # accepted format
    def convert_to_gitolite_format
      permissions = {}
      permissions['RW+'] = { '' => @rewind.uniq.sort } unless @rewind.empty?
      permissions['RW'] = { '' => @write.uniq.sort } unless @write.empty?
      permissions['R'] = { '' => @read.uniq.sort } unless @read.empty?

      [permissions]
    end
  end
end
