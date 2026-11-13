module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      set_current_user || reject_unauthorized_connection
    end

    private
      def set_current_user
        session_id = cookies.signed[:session_id]
        return unless session_id

        session = Session.includes(:user).find_by(id: session_id)
        if session&.user&.active?
          self.current_user = session.user
        end
      end
  end
end
