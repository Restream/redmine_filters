module RedmineFilters::Patches
  module IssueQueryPatch
    extend ActiveSupport::Concern

    included do
      self.available_columns << QueryColumn.new(
          :visit_count, :sortable => "#{IssueVisit.table_name}.visit_count", :default_order => 'desc')
    end

  end
end

unless IssueQuery.included_modules.include? RedmineFilters::Patches::IssueQueryPatch
  IssueQuery.send :include, RedmineFilters::Patches::IssueQueryPatch
end
