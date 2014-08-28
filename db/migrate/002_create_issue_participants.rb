class CreateIssueParticipants < ActiveRecord::Migration
  def change
    create_table :issue_participants do |t|
      t.references :issue, :null => false
      t.references :user
      t.integer :participant_role, :null => false, :default => 0
      t.datetime :date_begin
      t.datetime :date_end
    end
    add_index :issue_participants, :issue_id
    add_index :issue_participants, :user_id
  end
end
