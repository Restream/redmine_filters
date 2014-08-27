require File.expand_path('../../../test_helper', __FILE__)

class RedmineFilters::QueryTest < ActiveSupport::TestCase
  include Redmine::I18n

  fixtures :projects, :enabled_modules, :users, :members,
           :member_roles, :roles, :trackers, :issue_statuses,
           :issue_categories, :enumerations, :issues,
           :watchers, :custom_fields, :custom_values, :versions,
           :queries,
           :projects_trackers,
           :custom_fields_trackers

  def setup
    @user = User.find(1)
    User.current = @user
    @issue = Issue.find(1)
    @some_date = Date.today
    @issues_count = IssueQuery.new(:name => '_').issue_count
  end

  def test_last_viewed_by_me_on_some_date
    IssueVisit.save_visit(@issue, @user)
    query = IssueQuery.new(:name => '_', :group_by => 'status')
    query.add_filter('last_viewed_by_me_on', '=', [@some_date.to_s])
    assert query.has_filter?('last_viewed_by_me_on')
    assert_equal 1, query.issue_count
    assert_equal({ @issue.status => 1 }, query.issue_count_by_group)
    assert_equal 1, query.issues.length
    assert_equal [@issue.id], query.issue_ids
  end

  def test_last_viewed_by_me_on_none
    IssueVisit.save_visit(@issue, @user)
    query = IssueQuery.new(:name => '_', :group_by => 'status')
    query.add_filter('last_viewed_by_me_on', '!*')
    assert query.has_filter?('last_viewed_by_me_on')
    assert query.issues.many?
    refute query.issue_ids.include? @issue.id
  end

  def test_viewed_by_me_times
    @issue = Issue.find(2)
    5.times { IssueVisit.save_visit(@issue, @user) }
    query = IssueQuery.new(:name => '_')
    query.add_filter('viewed_by_me_times', '=', ['5'])
    assert query.has_filter?('viewed_by_me_times')
    assert_equal 1, query.issue_count
    assert_equal [@issue.id], query.issue_ids
  end

  def test_not_viewed_by_me_times
    IssueVisit.save_visit(@issue, @user)
    query = IssueQuery.new(:name => '_')
    query.add_filter('viewed_by_me_times', '!*')
    assert query.has_filter?('viewed_by_me_times')
    assert_equal @issues_count - 1, query.issue_count
    refute query.issue_ids.include?(@issue.id)
  end

  def test_created_by_me_on
    @issue.author = @user
    @issue.created_on = Time.now
    @issue.save!
    query = IssueQuery.new(:name => '_')
    query.add_filter('created_by_me_on', 't')
    assert query.has_filter?('created_by_me_on')
    assert_equal 1, query.issue_count
    assert_equal [@issue.id], query.issue_ids
  end

  def test_created_by_on_none_should_be_empty
    query = IssueQuery.new(:name => '_')
    query.add_filter('created_by_me_on', '!*')
    assert query.has_filter?('created_by_me_on')
    assert_equal 0, query.issue_count
  end

  def test_updated_by_me_on
    @issue.init_journal(@user, 'some notes')
    @issue.subject = 'new_subject'
    @issue.save
    query = IssueQuery.new(:name => '_')
    query.add_filter('updated_by_me_on', 't')
    assert query.has_filter?('updated_by_me_on')
    assert_equal 1, query.issue_count
    assert_equal [@issue.id], query.issue_ids
  end

  def test_updated_by_me_on_ignore_other_user_updates
    User.current = User.find(2)
    @issue.init_journal(User.current, 'some notes')
    @issue.subject = 'new_subject'
    @issue.save
    User.current = User.find(1)
    query = IssueQuery.new(:name => '_')
    query.add_filter('updated_by_me_on', 't')
    assert query.has_filter?('updated_by_me_on')
    assert_equal 0, query.issue_count
  end

  def test_updated_by_on_none_should_be_empty
    query = IssueQuery.new(:name => '_')
    query.add_filter('updated_by_me_on', '!*')
    assert query.has_filter?('updated_by_me_on')
    assert_equal 0, query.issue_count
  end

  def test_assigned_to_me_on
    @issue.init_journal(@user, 'assign user')
    @issue.assigned_to = @user
    @issue.save
    query = IssueQuery.new(:name => '_')
    query.add_filter('assigned_to_me_on', 't')
    assert query.has_filter?('assigned_to_me_on')
    assert_equal 1, query.issue_count
    assert_equal [@issue.id], query.issue_ids
  end

  def test_assigned_to_me_on_create
    User.current = User.find(3)
    query = IssueQuery.new(:name => '_')
    query.add_filter('assigned_to_me_on', '=', ['2006-07-19'])
    assert query.has_filter?('assigned_to_me_on')
    assert_equal 2, query.issue_count
    assert_equal [2, 3], query.issue_ids.sort
  end

  def test_assigned_to_me_on_none_should_be_empty
    query = IssueQuery.new(:name => '_')
    query.add_filter('assigned_to_me_on', '!*')
    assert query.has_filter?('assigned_to_me_on')
    assert_equal 0, query.issue_count
  end

  def test_unassigned_from_me_on
    @issue.init_journal(@user, 'assign user')
    @issue.assigned_to = @user
    @issue.save
    @issue.init_journal(@user, 'unassign user')
    @issue.assigned_to = nil
    @issue.save
    query = IssueQuery.new(:name => '_')
    query.add_filter('unassigned_from_me_on', 't')
    assert query.has_filter?('unassigned_from_me_on')
    assert_equal 1, query.issue_count
    assert_equal [@issue.id], query.issue_ids
  end

  def test_unassigned_from_me_on_none_should_be_empty
    query = IssueQuery.new(:name => '_')
    query.add_filter('unassigned_from_me_on', '!*')
    assert query.has_filter?('unassigned_from_me_on')
    assert_equal 0, query.issue_count
  end

  def test_updated_when_i_was_assignee_on
    @issue.init_journal(@user, 'assign user')
    @issue.assigned_to = @user
    @issue.save
    @issue.init_journal(@user, 'unassign user')
    @issue.subject = 'new subject'
    @issue.save
    query = IssueQuery.new(:name => '_')
    query.add_filter('updated_when_i_was_assignee_on', 't')
    assert query.has_filter?('updated_when_i_was_assignee_on')
    assert_equal 1, query.issue_count
    assert_equal [@issue.id], query.issue_ids
  end

  def test_updated_when_i_was_assignee_on_none_should_be_empty
    @issue.init_journal(@user, 'assign user')
    @issue.assigned_to = @user
    @issue.save
    @issue.init_journal(@user, 'unassign user')
    @issue.subject = 'new subject'
    @issue.save
    query = IssueQuery.new(:name => '_')
    query.add_filter('updated_when_i_was_assignee_on', '!*')
    assert query.has_filter?('updated_when_i_was_assignee_on')
    assert_equal 0, query.issue_count
  end

  def test_updated_after_i_was_assignee_on
    @issue.init_journal(@user, 'assign user')
    @issue.assigned_to = @user
    @issue.save
    @issue.init_journal(@user, 'unassign user')
    @issue.subject = 'new subject'
    @issue.save
    query = IssueQuery.new(:name => '_')
    query.add_filter('updated_after_i_was_assignee_on', 't')
    assert query.has_filter?('updated_after_i_was_assignee_on')
    assert_equal 1, query.issue_count
    assert_equal [@issue.id], query.issue_ids
  end

  def test_updated_after_i_was_assignee_on_none_should_be_empty
    @issue.init_journal(@user, 'assign user')
    @issue.assigned_to = @user
    @issue.save
    @issue.init_journal(@user, 'unassign user')
    @issue.subject = 'new subject'
    @issue.save
    query = IssueQuery.new(:name => '_')
    query.add_filter('updated_after_i_was_assignee_on', '!*')
    assert query.has_filter?('updated_after_i_was_assignee_on')
    assert_equal 0, query.issue_count
  end

  def test_issue_query_has_visit_count_column
    query = IssueQuery.new
    assert query.available_columns.detect { |c| c.name == :visit_count }
  end
end
