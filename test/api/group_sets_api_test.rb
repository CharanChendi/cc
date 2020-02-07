require 'test_helper'

class GroupSetsApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper
  include TestHelpers::TestFileHelper

  def app
    Rails.application
  end

  def test_post_add_a_new_groupset_to_a_unit_without_authorization
    # A dummy groupSet
    newGroupSet = FactoryBot.build(:group_set)

    # Create a unit
    newUnit = FactoryBot.create(:unit)
    
    # Obtain a student from the unit
    studentUser = newUnit.active_projects.first.student

    # Data that we want to post
    data_to_post = {
      unit_id: newUnit.id,
      group_set: newGroupSet
    }

    # Perform the POST
    post_json with_auth_token("/api/units/#{newUnit.id}/group_sets", studentUser), data_to_post

    # Check error code
    assert_equal 403, last_response.status
  end

  def test_post_add_a_new_groupset_to_a_unit_with_authorization
    # A dummy groupSet
    newGroupSet = FactoryBot.build(:group_set)

    # Create a unit
    newUnit = FactoryBot.create(:unit)
    
    # Data that we want to post
    data_to_post = {
      unit_id: newUnit.id,
      group_set: newGroupSet,
    }

    # perform the POST
    post_json with_auth_token("/api/units/#{newUnit.id}/group_sets", newUnit.main_convenor_user), data_to_post

    # check if the POST get through
    assert_equal 201, last_response.status
    #check response
    response_keys = %w(name allow_students_to_create_groups)
    responseGroupSet = GroupSet.find(last_response_body['id'])
    assert_json_matches_model(last_response_body,responseGroupSet,response_keys)
  end

  def test_get_all_groups_in_unit_with_authorization
    # Create a group
    newGroup = FactoryBot.create(:group)
    
    # Obtain the unit from the group
    newUnit = newGroup.group_set.unit
    get with_auth_token "/api/units/#{newUnit.id}/groups",newUnit.main_convenor_user

    #check returning number of groups
    assert_equal newUnit.groups.all.count, last_response_body.count
    
    #Check response
    response_keys = %w(id name)
    last_response_body.each do | data |
      grp = Group.find(data['id'])
      assert_json_matches_model(data, grp, response_keys)
    end
    assert_equal 200, last_response.status
  end

  def test_get_all_groups_in_unit_without_authorization
    # Create a group
    newGroup = FactoryBot.create(:group)
    # Obtain the unit of the group
    newUnit = newGroup.group_set.unit

    # Obtain student object from the unit
    studentUser = newUnit.active_projects.first.student
    get with_auth_token "/api/units/#{newUnit.id}/groups",studentUser
    # Check error code when an unauthorized user tries to get groups in a unit
    assert_equal 403, last_response.status
  end

end
