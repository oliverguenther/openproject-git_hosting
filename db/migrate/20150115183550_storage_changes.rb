class StorageChanges < ActiveRecord::Migration
  def self.up
    Repository::Git.find_each do |repo|
      repo.url = repo.git_path
      repo.root_url = repo.git_path
      repo.save
    end

    # Update settings
    Setting.plugin_openproject_revisions_git =
      Setting.plugin_openproject_revisions_git.merge(
        gitolite_global_storage_path: '/home/git/repositories',
        use_delayed_jobs: false
      )
  end

  def self.down
    # Use legacy path
    storage = Setting.plugin_openproject_revisions_git[:gitolite_global_storage_dir] || 'repositories'
    Repository::Git.find_each do |repo|
      repo.url = File.join(storage, repo.git_path)
      repo.root_url = File.join(storage, repo.git_path)
      repo.save
    end
  end
end
