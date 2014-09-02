module RedmineFilters::Hooks
  class IssueParticipantHooks < Redmine::Hook::Listener
    def controller_issues_new_after_save(context = {})
      issue = context[:issue]
      IssueParticipant.create(
          :issue => issue,
          :user => issue.assigned_to,
          :date_begin => issue.created_on
      )
    end

    def controller_issues_edit_after_save(context = {})
      issue = context[:issue]
      last_participant = IssueParticipant.where(:issue_id => issue.id).last
      last_participant.date_end = issue.updated_on
      last_participant.save
      IssueParticipant.create(
          :issue => issue,
          :user => issue.assigned_to,
          :date_begin => issue.updated_on
      )
    end
  end
end
