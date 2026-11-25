# frozen_string_literal: true

class HealthController < ActionController::Base
  def warm
    ActiveRecord::Base.connection.select_value("SELECT 1")
    render json: { status: "ok" }, status: :ok
  rescue ActiveRecord::ActiveRecordError
    render json: { status: "db_unavailable" }, status: :service_unavailable
  end
end
