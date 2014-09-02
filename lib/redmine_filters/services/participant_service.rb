module RedmineFilters::Services
  class ParticipantService
    class << self
      def update_assignees(&block)
        IssueParticipant.delete_all(:participant_role => IssueParticipant::ASSIGNEE)
        update_assignees_by_issue(&block)
        update_assignees_by_journal(&block)
      end

      def estimated_ticks
        journal_details = JournalDetail.joins(:journal).where(
            :property => 'attr',
            :prop_key => 'assigned_to_id',
            'journals.journalized_type' => 'Issue').count

        # for read and insert
        journal_details * 2
      end

      private

      def update_assignees_by_issue(&block)
        # User was assigned when issue created and was not changed later
        # (find issues without assignee change)
        IssueParticipant.connection.execute <<-SQL
          INSERT INTO issue_participants (issue_id, user_id, participant_role, date_begin)
          SELECT issues.id, issues.assigned_to_id, #{IssueParticipant::ASSIGNEE}, issues.created_on
          FROM issues
          WHERE
            NOT EXISTS (
              SELECT *
              FROM journals
                INNER JOIN journal_details ON journal_details.journal_id = journals.id
              WHERE
                journals.journalized_type = 'Issue' AND
                journals.journalized_id = issues.id AND
                journal_details.property = 'attr' AND
                journal_details.prop_key = 'assigned_to_id'
            )
        SQL
      end

      def update_assignees_by_journal(&block)
        issues = {}
        JournalDetail\
          .select('journal_details.id, issues.id as issue_id, issues.created_on, journals.created_on as updated_on, journal_details.old_value, journal_details.value')\
          .joins(:journal => [:issue])\
          .where(:property => 'attr', :prop_key => 'assigned_to_id', 'journals.journalized_type' => 'Issue')\
          .find_each do |detail|

          issues[detail.issue_id] ||= []
          issue = issues[detail.issue_id]

          if issue.empty?
            # first change of assignee

            # first assignee
            issue << {
                :issue_id => detail.issue_id,
                :user_id => detail.old_value && detail.old_value.to_i,
                :participant_role => IssueParticipant::ASSIGNEE,
                :date_begin => detail.created_on,
                :date_end => detail.updated_on
            }

            # second assignee
            issue << {
                :issue_id => detail.issue_id,
                :user_id => detail.value && detail.value.to_i,
                :participant_role => IssueParticipant::ASSIGNEE,
                :date_begin => detail.updated_on,
                :date_end => nil
            }

          else
            # next changes of assignee

            # previous assignee was assigned until this change
            issue.last[:date_end] = detail.updated_on

            # next assignee
            issue << {
                :issue_id => detail.issue_id,
                :user_id => detail.value && detail.value.to_i,
                :participant_role => IssueParticipant::ASSIGNEE,
                :date_begin => detail.updated_on,
                :date_end => nil
            }
          end
          block.call(1) if block_given?
        end

        participants = issues.values.flatten

        IssueParticipant.import!(participants, &block)
      end
    end
  end
end
