require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "assigns next sequential employee_code automatically" do
    user = User.create!(
      email_address: "baru@example.com",
      full_name: "Andi Wijaya",
      department: "Product",
      job_title: "Analyst",
      password: "password123",
      password_confirmation: "password123"
    )

    assert_equal "TM-103", user.employee_code
    assert_equal "member", user.role
    assert user.active?
    assert_not user.lead?
  end

  test "validates department and role" do
    user = users(:one)
    user.department = "UnknownDept"
    assert_not user.valid?

    user.department = "Engineering"
    user.role = "super_root"
    assert_not user.valid?
  end

  test "lead helper identifies team leads" do
    assert users(:two).lead?
    assert_not users(:one).lead?
  end
end
