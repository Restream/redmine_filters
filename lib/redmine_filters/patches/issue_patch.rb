module RedmineFilters::Patches
  module IssuePatch
    extend ActiveSupport::Concern

    included do
      has_many :participants, class_name: 'IssueParticipant'

      has_one :visit,
              -> { where("#{IssueVisit.table_name}.user_id = #{User.current.id}") },
              class_name: 'IssueVisit'

      delegate :visit_count, :last_visit_on, to: :visit, allow_nil: true

      scope :visible, lambda { |*args|
        joins(:project).includes(:project, :visit).where(Issue.visible_condition(args.shift || User.current, *args))
      }

      after_commit :insert_assignee_into_participants, on: :create
    end

    def author_with_participants
      ([author] + participants.map(&:user).to_a).uniq.compact
    end

    def author_with_updaters
      ([author] + updaters.to_a).uniq
    end

    def updaters
      journals.map(&:user).uniq
    end

    def insert_assignee_into_participants
      IssueParticipant.create(
        issue:            self,
        user:             assigned_to,
        participant_role: IssueParticipant::ASSIGNEE,
        date_begin:       created_on
      )
    end
  end
end

unless Issue.included_modules.include? RedmineFilters::Patches::IssuePatch
  Issue.send :include, RedmineFilters::Patches::IssuePatch
end
