module RedmineFilters::Hooks
  class IssueSidebarViewHooks < Redmine::Hook::ViewListener
    render_on :view_issues_sidebar_queries_bottom,
              partial: 'redmine_filters/sidebar_participants'
  end
end
