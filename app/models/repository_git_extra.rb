require 'digest/sha1'

class RepositoryGitExtra < ActiveRecord::Base
  unloadable

  belongs_to :repository, class_name: 'Repository', foreign_key: 'repository_id'

  validates_associated :repository

  attr_accessible :id, :repository_id, :key, :git_http, :git_daemon, :git_notify, :default_branch

  after_initialize :set_values

  private

  def set_values
    if repository.nil?
      generate
      setup_defaults
    end
  end

  def generate
    if key.nil?
      self.key = (0...64 + rand(64)).map { 65.+(rand(25)).chr }.join
    end
  end

  def setup_defaults
    self.git_http = Setting.plugin_openproject_revisions_git[:gitolite_http_by_default]
    self.git_daemon = Setting.plugin_openproject_revisions_git[:gitolite_daemon_by_default]
    self.git_notify = Setting.plugin_openproject_revisions_git[:gitolite_notify_by_default]
    self.default_branch = 'master'
  end
end
