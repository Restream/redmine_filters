module RedmineFilters::Patches
  module IssuePatch
    extend ActiveSupport::Concern

    included do
      has_many :participants, :class_name => 'IssueParticipant'

      has_one :visit,
              :class_name => 'IssueVisit',
              :conditions => proc { "#{IssueVisit.table_name}.user_id = #{User.current.id}" }

      delegate :visit_count, :last_visit_on, :to => :visit, :allow_nil => true

      scope :visible, lambda {|*args|
        includes(:project, :visit).where(Issue.visible_condition(args.shift || User.current, *args))
      }

    end
  end
end

unless Issue.included_modules.include? RedmineFilters::Patches::IssuePatch
  Issue.send :include, RedmineFilters::Patches::IssuePatch
end
