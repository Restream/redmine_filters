require 'redmine'

ActionDispatch::Callbacks.to_prepare do
  require 'redmine_filters'
end

Redmine::Plugin.register :redmine_filters do
  name        'Redmine Filters'
  description 'This plugin adds new filters to search through history (issue participants, issue visits)'
  author      'nodecarter'
  version     '0.0.2'
  url         'https://github.com/Undev/redmine_filters'

  requires_redmine :version_or_higher => '2.3.3'
end
