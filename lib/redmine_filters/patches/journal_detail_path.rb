module RedmineFilters::Patches
  module JournalDetailPatch
    extend ActiveSupport::Concern

    included do
      after_commit :insert_assignee_into_participants, :on => :create
    end

    def insert_assignee_into_participants
      return unless property == 'attr' && prop_key == 'assigned_to_id'
      issue = journal.issue
      last_participant = issue.participants.last
      last_participant.date_end = issue.updated_on
      last_participant.save
      IssueParticipant.create(
          :issue => issue,
          :user => issue.assigned_to,
          :participant_role => IssueParticipant::ASSIGNEE,
          :date_begin => issue.updated_on
      )
    end
  end
end

unless JournalDetail.included_modules.include? RedmineFilters::Patches::JournalDetailPatch
  JournalDetail.send :include, RedmineFilters::Patches::JournalDetailPatch
end
