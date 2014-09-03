module RedmineFilters::Patches
  module IssueQueryPatch
    extend ActiveSupport::Concern

    included do
      self.available_columns << QueryColumn.new(
          :visit_count,
          :sortable => "COALESCE(#{IssueVisit.table_name}.visit_count, 0)",
          :default_order => 'desc')
      self.available_columns << QueryColumn.new(
          :last_visit_on,
          :sortable => "COALESCE(#{IssueVisit.table_name}.last_visit_on, date('1900-01-01'))",
          :default_order => 'desc')

      alias_method_chain :initialize_available_filters, :rfs_patch
    end

    def initialize_available_filters_with_rfs_patch
      initialize_available_filters_without_rfs_patch

      # Filters based on issue_visit
      add_available_filter 'visit_count', :type => :integer
      add_available_filter 'last_visit_on', :type => :date_past

      # Filters based on issue_participant
      add_available_filter 'assigned_to_me_on', :type => :date_past
      add_available_filter 'unassigned_from_me_on', :type => :date_past
      add_available_filter 'updated_after_i_was_assignee_on', :type => :date_past

      # Additional filters based on existing data
      add_available_filter 'created_by_me_on', :type => :date_past
    end

    def sql_for_visit_count_field(field, operator, value)
      sql_for_field(field, operator, value, IssueVisit.table_name, field)
    end

    def sql_for_last_visit_on_field(field, operator, value)
      sql_for_field(field, operator, value, IssueVisit.table_name, field)
    end

    def sql_for_assigned_to_me_on_field(field, operator, value)
      part_t = IssueParticipant.table_name
      if value == '!*'
        <<-SQL
          NOT EXISTS (
            SELECT * FROM #{part_t}
            WHERE
              #{part_t}.issue_id = #{queried_table_name}.id AND
              #{part_t}.user_id = #{User.current.id}
          )
        SQL
      else
        sql_on_time = sql_for_field(field, operator, value, part_t, 'date_begin')
        <<-SQL
          EXISTS (
            SELECT * FROM #{part_t}
            WHERE
              #{part_t}.issue_id = #{queried_table_name}.id AND
              #{part_t}.user_id = #{User.current.id} AND
              (#{sql_on_time})
          )
        SQL
      end
    end

    def sql_for_updated_after_i_was_assignee_on_field(field, operator, value)
      part_t = IssueParticipant.table_name
      journal_t = Journal.table_name
      if value == '!*'
        '1=0'
      else
        sql_on_time = sql_for_field(field, operator, value, journal_t, 'created_on')
        <<-SQL
          #{queried_table_name}.assigned_to_id != #{User.current.id} AND
          EXISTS (
            SELECT * FROM #{part_t}
            WHERE
              #{part_t}.issue_id = #{queried_table_name}.id AND
              #{part_t}.user_id = #{User.current.id} AND
              #{part_t}.date_end IS NOT NULL
          ) AND
          EXISTS (
            SELECT * FROM #{journal_t}
            WHERE
              #{journal_t}.journalized_type = 'Issue' AND
              #{journal_t}.journalized_id = #{queried_table_name}.id AND
              #{sql_on_time}
          )
        SQL
      end
    end

    def sql_for_unassigned_from_me_on_field(field, operator, value)
      part_t = IssueParticipant.table_name
      if value == '!*'
        <<-SQL
          NOT EXISTS (
            SELECT * FROM #{part_t}
            WHERE
              #{part_t}.issue_id = #{queried_table_name}.id AND
              #{part_t}.user_id = #{User.current.id} AND
              #{part_t}.date_end IS NOT NULL
          )
        SQL
      else
        sql_on_time = sql_for_field(field, operator, value, part_t, 'date_end')
        <<-SQL
          EXISTS (
            SELECT * FROM #{part_t}
            WHERE
              #{part_t}.issue_id = #{queried_table_name}.id AND
              #{part_t}.user_id = #{User.current.id} AND
              (#{sql_on_time})
          )
        SQL
      end
    end

    def sql_for_created_by_me_on_field(field, operator, value)
      [
          '(',
          sql_for_field('created_on', operator, value, queried_table_name, 'created_on'),
          ' AND ',
          sql_for_field('author_id', '=', [User.current.id.to_s], queried_table_name, 'author_id'),
          ')'
      ].join
    end
  end
end

unless IssueQuery.included_modules.include? RedmineFilters::Patches::IssueQueryPatch
  IssueQuery.send :include, RedmineFilters::Patches::IssueQueryPatch
end
