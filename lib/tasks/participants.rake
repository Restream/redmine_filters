namespace :redmine_filters do

  desc 'Update issue_participant table from journal'
  task :update_participants => :environment do
    RedmineFilters::Services::ParticipantService.update_from_journal
  end

end
