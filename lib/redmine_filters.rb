module RedmineFilters
end

require 'active_support/concern'
require 'redmine_filters/hooks/issue_sidebar_view_hooks'
require 'redmine_filters/hooks/issue_visit_view_hooks'
require 'redmine_filters/hooks/style_view_hooks'
require 'redmine_filters/patches/issue_patch'
require 'redmine_filters/patches/journal_detail_path'
require 'redmine_filters/patches/issue_query_patch'
require 'redmine_filters/services/participant_service'
