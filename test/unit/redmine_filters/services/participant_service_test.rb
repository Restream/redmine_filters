require File.expand_path('../../../../test_helper', __FILE__)

class RedmineFilters::Services::ParticipantServiceTest < ActiveSupport::TestCase
  fixtures :users, :user_preferences, :roles, :projects, :members, :member_roles,
           :issues, :issue_statuses, :trackers, :enumerations, :custom_fields,
           :auth_sources, :projects_trackers, :enabled_modules, :journals, :journal_details

  def test_update_assignees_by_issue
    RedmineFilters::Services::ParticipantService.send :update_assignees_by_issue
    issues_count = Issue.count
    participants_count = IssueParticipant.assignees.count
    assert_equal issues_count, participants_count
    Issue.all.each do |issue|
      participants = issue.participants.assignees
      assert_equal 1, participants.count
      assert_equal issue.assigned_to_id, participants.first.user_id
      assert_equal issue.created_on, participants.first.date_begin
      assert_equal nil, participants.first.date_end
    end
  end


  def test_update_assignees
    Issue.delete_all('id != 1')
    user = User.find(1)
    issue = Issue.find(1)

    update_1_on = change_assignee(2)
    update_2_on = change_assignee(nil)
    update_3_on = change_assignee(3)

    RedmineFilters::Services::ParticipantService.update_assignees

    participants = issue.participants.assignees
    assert_equal 4, participants.count

    assert_equal nil, participants[0].user_id
    assert_equal issue.created_on.to_s, participants[0].date_begin.to_s
    assert_equal update_1_on, participants[0].date_end.to_s

    assert_equal 2, participants[1].user_id
    assert_equal update_1_on, participants[1].date_begin.to_s
    assert_equal update_2_on, participants[1].date_end.to_s

    assert_equal nil, participants[2].user_id
    assert_equal update_2_on, participants[2].date_begin.to_s
    assert_equal update_3_on, participants[2].date_end.to_s

    assert_equal 3, participants[3].user_id
    assert_equal update_3_on, participants[3].date_begin.to_s
    assert_equal nil, participants[3].date_end
  end

  def change_assignee(assigned_to_id)
    sleep 2
    issue = Issue.find(1)
    issue.init_journal(User.current, 'update 2')
    issue.assigned_to_id = assigned_to_id
    issue.save!
    issue.updated_on.to_s
  end


end
