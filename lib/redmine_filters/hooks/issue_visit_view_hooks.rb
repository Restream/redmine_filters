module RedmineFilters::Hooks
  class IssueVisitViewHooks < Redmine::Hook::ViewListener
    def view_issues_show_details_bottom(context = {})
      ::IssueVisit.save_visit(context[:issue]) if User.current.logged?
      nil
    end
  end
end
