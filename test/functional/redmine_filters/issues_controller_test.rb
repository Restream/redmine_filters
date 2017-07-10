require File.expand_path('../../../test_helper', __FILE__)

class RedmineFilters::IssuesControllerTest < ActionController::TestCase
  fixtures :users, :user_preferences, :roles, :projects, :members, :member_roles, :email_addresses,
           :issues, :issue_statuses, :trackers, :enumerations, :custom_fields,
           :auth_sources, :projects_trackers, :enabled_modules, :journals, :journal_details

  def setup
    @controller                = IssuesController.new
    @request                   = ActionController::TestRequest.new
    @user                      = User.find(2)
    @request.session[:user_id] = @user.id
    @project                   = Project.find(1)
  end

  def test_issue_visit_saved
    issue = Issue.visible(@user).first
    assert issue
    get :show, id: issue.id
    visit = IssueVisit.find_by_issue(issue, @user)
    assert visit
    assert_equal 1, visit.visit_count
  end

  def test_issue_visit_count
    issue = Issue.visible(@user).first
    assert issue
    5.times { get :show, id: issue.id }
    visit = IssueVisit.find_by_issue(issue, @user)
    assert visit
    assert_equal 5, visit.visit_count
  end

  def test_issue_visit_time
    issue = Issue.visible(@user).first
    assert issue
    get :show, id: issue.id
    after_first_visit = Time.now
    sleep 1
    get :show, id: issue.id
    sleep 1
    after_last_visit = Time.now
    visit            = IssueVisit.find_by_issue(issue, @user)
    assert visit
    assert visit.last_visit_on.between?(after_first_visit, after_last_visit)
  end

  def test_participant_created_on_issue_create_with_assignee
    @request.session[:user_id] = 2
    post :create, project_id: 1,
         issue:               { tracker_id:      3,
                                status_id:       2,
                                assigned_to_id:  3,
                                subject:         'This is the test_new issue with assignee',
                                description:     'This is the description',
                                priority_id:     5,
                                start_date:      '2010-11-07',
                                estimated_hours: '' }

    issue        = Issue.find_by_subject('This is the test_new issue with assignee')
    participants = issue.participants
    assert_equal 1, participants.count
    participant = participants[0]
    assert_equal 3, participant.user_id
    assert_equal issue.created_on, participant.date_begin
    assert_equal nil, participant.date_end
  end

  def test_participant_created_on_issue_create_with_group_assignee
    with_settings :issue_group_assignment => '1' do
      @request.session[:user_id] = 1
      post :create, project_id: 2,
           issue:               { tracker_id:      1,
                                  status_id:       2,
                                  assigned_to_id:  11,
                                  subject:         'This is the test_new issue assigned to group',
                                  description:     'This is the description',
                                  priority_id:     5,
                                  start_date:      '2010-11-07',
                                  estimated_hours: '' }

      issue        = Issue.find_by_subject('This is the test_new issue assigned to group')
      participants = issue.participants
      assert_equal 1, participants.count
      participant = participants[0]
      assert_equal 11, participant.user_id
      assert_equal issue.created_on, participant.date_begin
      assert_equal nil, participant.date_end
    end
  end

  def test_participant_created_on_issue_create_without_assignee
    @request.session[:user_id] = 2
    post :create, project_id: 1,
         issue:               { tracker_id:      3,
                                status_id:       2,
                                subject:         'This is the test_new issue without assignee',
                                description:     'This is the description',
                                priority_id:     5,
                                start_date:      '2010-11-07',
                                estimated_hours: '' }

    issue        = Issue.find_by_subject('This is the test_new issue without assignee')
    participants = issue.participants
    assert_equal 1, participants.count
    participant = participants[0]
    assert_equal nil, participant.user_id
    assert_equal issue.created_on, participant.date_begin
    assert_equal nil, participant.date_end
  end

  def test_participant_created_on_issue_update
    # fill up participants before update
    RedmineFilters::Services::ParticipantService.update_assignees

    put :update, id: 1, issue: { subject: 'changed', assigned_to_id: 2 }
    issue        = Issue.find(1)
    participants = issue.participants.order(:date_begin)
    assert_equal 2, participants.count
    prev_participant = participants[0]
    last_participant = participants[1]
    assert_equal nil, prev_participant.user_id
    assert_equal issue.updated_on, prev_participant.date_end
    assert_equal 2, last_participant.user_id
    assert_equal issue.updated_on, last_participant.date_begin
    assert_equal nil, last_participant.date_end
  end

  def test_participant_block_showed_in_sidebar
    updater = User.find(1)
    issue   = Issue.find(1)
    issue.init_journal(updater, 'some update')
    issue.assigned_to_id = 3
    issue.save

    RedmineFilters::Services::ParticipantService.update_assignees

    get :show, id: issue.id

    assert_select "div#sidebar ul.participants li a:match('href', ?)", /\/users\/2/, 'participants should include author'
    assert_select "div#sidebar ul.participants li a:match('href', ?)", /\/users\/3/, 'participants should include assignee'
    assert_select "div#sidebar ul.updaters li a:match('href', ?)", /\/users\/2/, 'updaters should include author'
    assert_select "div#sidebar ul.updaters li a:match('href', ?)", /\/users\/1/, 'updaters should include all updaters'
  end
end
