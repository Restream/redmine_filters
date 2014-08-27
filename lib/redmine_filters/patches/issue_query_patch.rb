module RedmineFilters::Patches
  module IssueQueryPatch
    extend ActiveSupport::Concern

    included do
      self.available_columns << QueryColumn.new(
          :visit_count,
          :sortable => "#{IssueVisit.table_name}.visit_count",
          :default_order => 'desc')
      self.available_columns << QueryColumn.new(
          :last_visit_on,
          :sortable => "#{IssueVisit.table_name}.last_visit_on",
          :default_order => 'desc')

      alias_method_chain :initialize_available_filters, :rfs_patch
    end

    def initialize_available_filters_with_rfs_patch
      initialize_available_filters_without_rfs_patch

      # Filters based on issue_visit
      add_available_filter 'visit_count', :type => :integer
      add_available_filter 'last_visit_on', :type => :date_past
    end

    def sql_for_visit_count_field(field, operator, value)
      sql_for_field(field, operator, value, IssueVisit.table_name, field)
    end

    def sql_for_last_visit_on_field(field, operator, value)
      sql_for_field(field, operator, value, IssueVisit.table_name, field)
    end
  end
end

unless IssueQuery.included_modules.include? RedmineFilters::Patches::IssueQueryPatch
  IssueQuery.send :include, RedmineFilters::Patches::IssueQueryPatch
end
