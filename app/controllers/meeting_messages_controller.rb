class MeetingMessagesController < ApplicationController
  before_action :set_project
  before_action :set_meeting

  def create
    @message = @meeting.meeting_messages.build(message_params)
    @message.user = current_user

    if @message.save
      respond_to do |format|
        format.turbo_stream { head :ok }
        format.html { redirect_to project_meeting_path(@project, @meeting) }
      end
    else
      redirect_to project_meeting_path(@project, @meeting), alert: @message.errors.full_messages.to_sentence
    end
  end

  private
    def set_project
      load_authorized_project(:project_id)
    end

    def set_meeting
      @meeting = @project.meetings.find(params[:meeting_id])
    end

    def message_params
      params.require(:meeting_message).permit(:body, :kind)
    end
end
