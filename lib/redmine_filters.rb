module RedmineFilters
end

require 'active_support/concern'

require_dependency 'redmine_filters/hooks/issue_sidebar_view_hooks'
require_dependency 'redmine_filters/hooks/issue_visit_view_hooks'
require_dependency 'redmine_filters/hooks/style_view_hooks'
require_dependency 'redmine_filters/patches/issue_patch'
require_dependency 'redmine_filters/patches/journal_detail_patch'
require_dependency 'redmine_filters/patches/issue_query_patch'
require_dependency 'redmine_filters/services/participant_service'

ActionDispatch::Callbacks.to_prepare do

  unless Issue.included_modules.include? RedmineFilters::Patches::IssuePatch
    Issue.send :include, RedmineFilters::Patches::IssuePatch
  end

  unless JournalDetail.included_modules.include? RedmineFilters::Patches::JournalDetailPatch
    JournalDetail.send :include, RedmineFilters::Patches::JournalDetailPatch
  end

  unless IssueQuery.included_modules.include? RedmineFilters::Patches::IssueQueryPatch
    IssueQuery.send :include, RedmineFilters::Patches::IssueQueryPatch
  end

end
