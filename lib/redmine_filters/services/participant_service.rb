module RedmineFilters::Services
  class ParticipantService
    class << self
      def update_from_journal
        IssueParticipant.transaction do
          IssueParticipant.delete_all
          update_1
          update_2
          max_assignee_changes = Journal.where(:journalized_type => 'Issue').order('count(*) DESC').limit(1)
            .count(:joins => "INNER JOIN journal_details d ON d.journal_id = journals.id AND d.property = 'attr' AND d.prop_key = 'assigned_to_id'",
                   :group => 'journals.journalized_id').values[0] || 1
          max_assignee_changes.times { update_3 }
        end
      end

      def update_1
        # User was assigned when issue created and was not changed later
        # (find issues without assignee change)
        IssueParticipant.connection.execute <<-SQL
          INSERT INTO issue_participants (issue_id, user_id, participant_role, date_begin)
          SELECT issues.id, issues.assigned_to_id, 0, issues.created_on
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

      def update_2
        # User was assigned when issue created and he WAS CHANGED later
        # (find the first change of Issue#assigned_to)
        IssueParticipant.connection.execute <<-SQL
          INSERT INTO issue_participants (issue_id, user_id, participant_role, date_begin, date_end)
          SELECT i.id, CAST(d.old_value AS INTEGER), 0, i.created_on, j.created_on
          FROM issues i
            INNER JOIN journals j ON j.journalized_type = 'Issue' AND j.journalized_id = i.id
              INNER JOIN journal_details d ON d.journal_id = j.id
          WHERE
            j.id = (SELECT MIN(j2.id)
                    FROM journals j2
                      INNER JOIN journal_details d2 ON d2.journal_id = j2.id
                    WHERE
                      j2.journalized_id = i.id AND
                      d2.property = 'attr' AND
                      d2.prop_key = 'assigned_to_id') AND
            d.property = 'attr' AND
            d.prop_key = 'assigned_to_id'
        SQL
      end

      def update_3
        # find other changes of assignee
        IssueParticipant.connection.execute <<-SQL
          INSERT INTO issue_participants (issue_id, user_id, participant_role, date_begin, date_end)
          SELECT i.id, CAST(d.value AS INTEGER), 0, j.created_on,
            ( SELECT MIN(j2.created_on)
              FROM journals j2
                INNER JOIN journal_details d2 ON
                    d2.journal_id = j2.id AND
                    d2.property = 'attr' AND
                    d2.prop_key = 'assigned_to_id'
              WHERE
                j2.journalized_type = 'Issue' AND
                j2.journalized_id = i.id AND
                j2.created_on > j.created_on )
          FROM
            issues i
              INNER JOIN issue_participants p ON p.issue_id = i.id
              INNER JOIN journals j ON j.journalized_type = 'Issue' AND
                                       j.journalized_id = p.issue_id AND
                                       j.created_on = p.date_end
              INNER JOIN journal_details d ON d.journal_id = j.id
            WHERE
              p.id = (SELECT MAX(p_max.id) FROM issue_participants p_max WHERE p_max.issue_id = p.issue_id) AND
              p.date_end IS NOT NULL AND
              d.property = 'attr' AND
              d.prop_key = 'assigned_to_id'
        SQL
      end
    end
  end
end
