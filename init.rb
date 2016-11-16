require 'redmine'

Redmine::Plugin.register :redmine_filters do
  name 'Redmine Filters'
  description 'This plugin adds new filters to search through history (issue participants, issue visits)'
  author 'Restream'
  version '0.1.0'
  url 'https://github.com/Restream/redmine_filters'

  requires_redmine version_or_higher: '3.0.0'
end

require 'redmine_filters'
