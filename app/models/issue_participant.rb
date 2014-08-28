class IssueParticipant < ActiveRecord::Base
  ASSIGNEE = 0
  WATCHER = 1

  belongs_to :issue
  belongs_to :user

end
