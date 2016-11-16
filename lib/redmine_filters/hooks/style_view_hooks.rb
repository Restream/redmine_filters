module RedmineFilters::Hooks
  class StyleViewHooks < Redmine::Hook::ViewListener
    def view_layouts_base_html_head(_ = {})
      stylesheet_link_tag 'redmine_filters', plugin: 'redmine_filters'
    end
  end
end
