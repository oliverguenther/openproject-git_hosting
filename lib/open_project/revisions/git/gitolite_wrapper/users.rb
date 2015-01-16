module OpenProject::Revisions::Git::GitoliteWrapper
  class Users < Admin
    def add_ssh_key
      key = @object_id
      logger.info("Adding SSH key for user '#{key.user.login}'")
      @admin.transaction do
        add_gitolite_key(key)
        gitolite_admin_repo_commit("#{key.title} for #{key.user.login}")
      end
    end

    def delete_ssh_key
      key = @object_id
      logger.info("Deleting SSH key #{key[:identifier]}")
      @admin.transaction do
        remove_gitolite_key(key)
        gitolite_admin_repo_commit("#{key[:title]}")
      end
    end

    def update_all_ssh_keys_forced
      users = User.includes(:gitolite_public_keys).all.select { |u| u.gitolite_public_keys.any? }
      @admin.transaction do
        users.each do |user|
          user.gitolite_public_keys.each do |key|
            add_gitolite_key key
          end
        end
        gitolite_admin_repo_commit("Added SSH keys for #{users.size} users")
      end
    end

    private

    def add_gitolite_key(key)
      parts = key.key.split
      repo_keys = @admin.ssh_keys[key.identifier]
      repo_key = repo_keys.select { |k| k.location == key.title && k.ownidentifierer == key.identifier }.first
      if repo_key
        logger.info("#{@action} : SSH key '#{key.identifier}@#{key.location}' exists, removing first ...")
        @admin.rm_key(repo_key)
      end

      repo_key = Gitolite::SSHKey.new(parts[0], parts[1], parts[2], key.identifier, key.title)
      @admin.add_key(repo_key)
    end

    def remove_gitolite_key(key)
      repo_keys = @admin.ssh_keys[key[:owner]]
      repo_key = repo_keys.select { |k| k.location == key[:location] && k.owner == key[:owner] }.first

      if repo_key
        @admin.rm_key(repo_key)
      else
        logger.info("#{@action} : SSH key '#{key[:owner]}@#{key[:location]}' does not exits in Gitolite, exit !")
        false
      end
    end
  end
end
