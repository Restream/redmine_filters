require 'ansi/progressbar'

namespace :redmine_filters do

  desc 'Update issue_participant table from journal'
  task :update_participants => :environment do
    ticks = RedmineFilters::Services::ParticipantService.estimated_ticks
    bar = ANSI::ProgressBar.new('Progress', ticks)
    bar.flush
    RedmineFilters::Services::ParticipantService.update_assignees do |ticks|
      bar.inc(ticks)
    end
    bar.finish
    puts 'Done update participants.'
  end

end
