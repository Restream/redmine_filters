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

      principals = available_principals
      principal_values = []
      principal_values << ["<< #{l(:label_me)} >>", 'me'] if User.current.logged?
      principal_values += principals.collect{ |s| [s.name, s.id.to_s] }

      # Filters based on issue_visit
      add_available_filter 'visit_count', :type => :integer
      add_available_filter 'last_visit_on', :type => :date_past

      # Filters based on issue_participant
      add_available_filter 'assigned_to_me_on', :type => :date_past
      add_available_filter 'unassigned_from_me_on', :type => :date_past
      add_available_filter 'updated_after_i_was_assignee_on', :type => :date_past
      add_available_filter 'updated_when_i_was_assignee_on', :type => :date_past

      # Additional filters based on existing data
      add_available_filter 'created_by_me_on', :type => :date_past
      add_available_filter 'updated_by_me_on', :type => :date_past

      if principal_values.any?
        add_available_filter 'updated_by', :type => :list_optional, :values => principal_values
        add_available_filter 'participant', :type => :list_optional, :values => principal_values
      end
    end

    def available_principals
      principals = []
      if project
        principals += project.principals.sort
        unless project.leaf?
          subprojects = project.descendants.visible.all
          principals += Principal.member_of(subprojects)
        end
      else
        if all_projects.any?
          principals += Principal.member_of(all_projects)
        end
      end
      principals.uniq!
      principals.sort!
      principals
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
          (#{queried_table_name}.assigned_to_id IS NULL OR
           #{queried_table_name}.assigned_to_id != #{User.current.id}) AND
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
              #{journal_t}.created_on > (
                SELECT MAX(#{part_t}.date_end)
                FROM #{part_t}
                WHERE
                  #{part_t}.issue_id = #{queried_table_name}.id AND
                  #{part_t}.user_id = #{User.current.id} AND
                  #{part_t}.date_end IS NOT NULL
              ) AND
              (#{sql_on_time})
          )
        SQL
      end
    end

    def sql_for_updated_when_i_was_assignee_on_field(field, operator, value)
      part_t = IssueParticipant.table_name
      journal_t = Journal.table_name
      if value == '!*'
        '1=0'
      else
        sql_on_time = sql_for_field(field, operator, value, journal_t, 'created_on')
        <<-SQL
          EXISTS (
            SELECT * FROM #{journal_t}
              INNER JOIN #{part_t} ON
                #{part_t}.issue_id = #{journal_t}.journalized_id AND
                #{part_t}.user_id = #{User.current.id} AND
                (
                  #{part_t}.date_begin <= #{journal_t}.created_on AND
                  (#{part_t}.date_end IS NULL OR #{part_t}.date_end > #{journal_t}.created_on)
                )
            WHERE
              #{journal_t}.journalized_type = 'Issue' AND
              #{journal_t}.journalized_id = #{queried_table_name}.id AND
              (#{sql_on_time})
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

    def sql_for_updated_by_me_on_field(field, operator, value)
      journal_t = Journal.table_name
      if value == '!*'
        <<-SQL
          NOT EXISTS (
            SELECT * FROM #{journal_t}
            WHERE
              #{journal_t}.journalized_type = 'Issue' AND
              #{journal_t}.journalized_id = #{queried_table_name}.id) AND
              #{journal_t}.user_id = #{User.current.id}
        SQL
      else
        sql_on_time = sql_for_field(field, operator, value, journal_t, 'created_on')
        <<-SQL
          EXISTS (
            SELECT * FROM #{journal_t}
            WHERE
              #{journal_t}.journalized_type = 'Issue' AND
              #{journal_t}.journalized_id = #{Issue.table_name}.id AND
              #{journal_t}.user_id = #{User.current.id} AND
              (#{sql_on_time}))
        SQL
      end
    end

    def sql_for_updated_by_field(field, operator, value)
      replace_keyword_me_with_current_user_id(value)
      value = replace_group_id_with_user_ids(value)
      journal_t = Journal.table_name
      sql_user_id = sql_for_field(field, operator, value, journal_t, 'user_id')
      <<-SQL
        EXISTS (
          SELECT * FROM #{journal_t}
          WHERE
            #{journal_t}.journalized_type = 'Issue' AND
            #{journal_t}.journalized_id = #{Issue.table_name}.id AND
            (#{sql_user_id}))
      SQL
    end

    def sql_for_participant_field(field, operator, value)
      replace_keyword_me_with_current_user_id(value)
      value = replace_group_id_with_user_ids(value)
      part_t = IssueParticipant.table_name
      sql_user_id = sql_for_field(field, operator, value, part_t, 'user_id')
      <<-SQL
        EXISTS (
          SELECT * FROM #{part_t}
          WHERE #{part_t}.issue_id = #{queried_table_name}.id AND (#{sql_user_id}))
      SQL
    end

    def replace_group_id_with_user_ids(value)
      Group.all.each do |group|
        value += group.users.map { |u| u.id.to_s } if value.delete(group.id.to_s)
      end
      value
    end

    def replace_keyword_me_with_current_user_id(value)
      value.push(User.current.logged? ? User.current.id.to_s : '0') if value.delete('me')
    end
  end
end

unless IssueQuery.included_modules.include? RedmineFilters::Patches::IssueQueryPatch
  IssueQuery.send :include, RedmineFilters::Patches::IssueQueryPatch
end
