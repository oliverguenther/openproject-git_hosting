class AddFingerprintToGitolitePublicKeys < ActiveRecord::Migration
  def self.up
    add_column :gitolite_public_keys, :fingerprint, :string, null: false
    add_index :gitolite_public_keys, :fingerprint
  end

  def self.down
    remove_index :gitolite_public_keys, :fingerprint
    remove_column :gitolite_public_keys, :fingerprint
  end
end
