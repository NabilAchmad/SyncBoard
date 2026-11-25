# frozen_string_literal: true

require "test_helper"

class HealthWarmTest < ActionDispatch::IntegrationTest
  test "warm endpoint pings database without requiring authentication" do
    get rails_warm_health_check_path
    assert_response :success
    assert_equal({ "status" => "ok" }, response.parsed_body)
  end
end
