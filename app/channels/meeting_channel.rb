class MeetingChannel < ApplicationCable::Channel
  def subscribed
    @meeting = Meeting.includes(project: :team).find_by(id: params[:meeting_id])
    return reject unless @meeting && current_user&.active? && current_user.member_of?(@meeting.project.team)

    stream_for @meeting
  end

  def unsubscribed
    return unless @meeting && params[:client_id].present?

    self.class.broadcast_to(@meeting, {
      type: "peer_left",
      sender_id: params[:client_id],
      user_id: current_user.id
    })
  end

  def join(data)
    return unless @meeting && data["client_id"].present?

    self.class.broadcast_to(@meeting, {
      type: "peer_joined",
      sender_id: data["client_id"],
      target_id: data["target_id"],
      audio_enabled: !!data["audio_enabled"],
      video_enabled: !!data["video_enabled"],
      screen_sharing: !!data["screen_sharing"],
      user: serialized_user
    })
  end

  def leave(data)
    return unless @meeting && data["client_id"].present?

    self.class.broadcast_to(@meeting, {
      type: "peer_left",
      sender_id: data["client_id"],
      user_id: current_user.id
    })
  end

  def signal(data)
    return unless @meeting && data["client_id"].present?

    self.class.broadcast_to(@meeting, {
      type: "signal",
      signal_type: data["signal_type"],
      sender_id: data["client_id"],
      target_id: data["target_id"],
      payload: data["payload"],
      audio_enabled: !!data["audio_enabled"],
      video_enabled: !!data["video_enabled"],
      screen_sharing: !!data["screen_sharing"],
      user: serialized_user
    })
  end

  def media_state(data)
    return unless @meeting && data["client_id"].present?

    self.class.broadcast_to(@meeting, {
      type: "media_state",
      sender_id: data["client_id"],
      audio_enabled: !!data["audio_enabled"],
      video_enabled: !!data["video_enabled"],
      screen_sharing: !!data["screen_sharing"]
    })
  end

  def transcript_chunk(data)
    return unless @meeting && data["client_id"].present?

    text = data["text"].to_s.strip
    return if text.blank?

    allowed_tags = %w[point decision action blocker].freeze
    tag = allowed_tags.include?(data["tag"].to_s) ? data["tag"].to_s : "point"

    self.class.broadcast_to(@meeting, {
      type: "transcript_chunk",
      sender_id: data["client_id"],
      speaker: current_user.full_name,
      text: text,
      tag: tag
    })
  end

  private
    def serialized_user
      {
        id: current_user.id,
        full_name: current_user.full_name,
        initials: current_user.initials,
        job_title: current_user.job_title,
        role_label: current_user.lead_of?(@meeting.project.team) ? "Team Lead" : "Anggota Tim",
        lead: current_user.lead_of?(@meeting.project.team)
      }
    end
end
