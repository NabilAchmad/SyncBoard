class MeetingsController < ApplicationController
  before_action :set_project
  before_action :set_meeting, except: :create
  before_action :require_lead!, only: %i[approve reject]
  before_action :require_moderator!, only: %i[toggle_item add_action_item update_action_item]
  before_action :require_host!, only: :end_call

  def create
    existing_meeting = nil
    created = false

    @project.with_lock do
      existing_meeting = @project.meetings.open_rooms.recent_first.first
      next if existing_meeting

      @meeting = @project.meetings.build(meeting_params)
      @meeting.host = current_user
      @meeting.status = "live"

      if @meeting.save
        @project.activity_logs.create!(
          user: current_user,
          meeting: @meeting,
          summary: "#{current_user.full_name} membuka ruang diskusi '#{@meeting.title}' (#{@meeting.room_code})"
        )
        @meeting.meeting_messages.create!(
          user: current_user,
          kind: "system",
          body: "Ruang diskusi & video call dibuka oleh #{current_user.full_name}."
        )
        created = true
      end
    end

    if existing_meeting
      redirect_to project_meeting_path(@project, existing_meeting),
        notice: "Ruang meeting #{existing_meeting.room_code} sudah terbuka. Anda bergabung ke room aktif."
    elsif created
      @project.broadcast_meeting_refresh!
      redirect_to project_meeting_path(@project, @meeting), notice: "Ruang meeting #{@meeting.room_code} siap digunakan!"
    else
      redirect_to @project, alert: @meeting.errors.full_messages.to_sentence
    end
  end

  def show
    @team_members = @project.team.active_members_with_avatars
    users_by_id = @team_members.index_by(&:id)
    @project_tasks = @project.tasks.ordered_for_board.to_a
    tasks_by_id = @project_tasks.index_by(&:id)

    preload_records_with_known_map([ @meeting ], :approved_by_id, :approved_by, users_by_id)
    ActiveRecord::Associations::Preloader.new(records: [ @meeting ], associations: :meeting_action_items).call
    action_items = @meeting.meeting_action_items.to_a
    preload_records_with_known_map(action_items, :assignee_id, :assignee, users_by_id)
    preload_records_with_known_map(action_items, :target_task_id, :target_task, tasks_by_id)

    @messages = @meeting.meeting_messages.chronological.to_a
    @messages.each { |message| message.association(:meeting).target = @meeting }
    preload_records_with_known_map(
      @messages,
      :user_id,
      :user,
      users_by_id,
      fallback_preload: { user: { avatar_attachment: :blob } }
    )

    @new_message = MeetingMessage.new(meeting: @meeting, kind: "chat")
  end

  def save_transcript
    if @meeting.update(transcript_text: params[:transcript_text].to_s)
      respond_to do |format|
        format.json { render json: { saved: true, updated_at: @meeting.updated_at.strftime("%H:%M:%S") } }
        format.html { redirect_to project_meeting_path(@project, @meeting), notice: "Transcript & catatan rapat tersimpan." }
      end
    else
      respond_to do |format|
        format.json { render json: { saved: false, errors: @meeting.errors.full_messages }, status: :unprocessable_entity }
        format.html { redirect_to project_meeting_path(@project, @meeting), alert: "Gagal menyimpan transcript." }
      end
    end
  end

  def generate_summary
    if params.key?(:transcript_text)
      @meeting.update!(transcript_text: params[:transcript_text].to_s)
    end

    Meetings::SummaryGenerator.new(meeting: @meeting, actor: current_user).call
    @project.broadcast_meeting_refresh!

    respond_to do |format|
      format.turbo_stream { render_summary_panel_turbo_stream }
      format.html { redirect_to project_meeting_path(@project, @meeting), notice: "Rangkuman & usulan perubahan Kanban berhasil dibuat. Menunggu ACC Team Lead." }
    end
  end

  def toggle_item
    item = @meeting.meeting_action_items.find(params[:item_id])
    unless item.applied?
      item.update!(selected: !item.selected?)
      @meeting.broadcast_summary_refresh!
    end

    respond_to do |format|
      format.turbo_stream { render_summary_panel_turbo_stream }
      format.html { redirect_to project_meeting_path(@project, @meeting) }
    end
  end

  def add_action_item
    item = @meeting.meeting_action_items.build(selected: true)
    unless apply_normalized_action_item_params(item)
      redirect_to project_meeting_path(@project, @meeting), alert: item.errors.full_messages.to_sentence
      return
    end

    if item.save
      @meeting.update!(status: "summary_ready") if @meeting.live? || @meeting.ended? || @meeting.rejected?
      @meeting.broadcast_summary_refresh!
      respond_to do |format|
        format.turbo_stream { render_summary_panel_turbo_stream }
        format.html { redirect_to project_meeting_path(@project, @meeting), notice: "Usulan perubahan ditambahkan ke daftar review." }
      end
    else
      redirect_to project_meeting_path(@project, @meeting), alert: item.errors.full_messages.to_sentence
    end
  end

  def update_action_item
    item = @meeting.meeting_action_items.find(params[:item_id])
    if @meeting.approved? || item.applied?
      redirect_to project_meeting_path(@project, @meeting), alert: "Usulan yang sudah diterapkan ke Kanban tidak dapat diubah."
      return
    end

    unless apply_normalized_action_item_params(item)
      redirect_to project_meeting_path(@project, @meeting), alert: item.errors.full_messages.to_sentence
      return
    end

    if item.save
      @meeting.broadcast_summary_refresh!
      respond_to do |format|
        format.turbo_stream { render_summary_panel_turbo_stream }
        format.html { redirect_to project_meeting_path(@project, @meeting), notice: "Usulan aksi Kanban diperbarui." }
      end
    else
      redirect_to project_meeting_path(@project, @meeting), alert: item.errors.full_messages.to_sentence
    end
  end

  def end_call
    has_notes = @meeting.transcript_text.present? || @meeting.meeting_messages.where(kind: %w[decision note]).exists?

    if has_notes && !@meeting.approved?
      @meeting.update!(ended_at: @meeting.ended_at || Time.current)
      Meetings::SummaryGenerator.new(meeting: @meeting, actor: current_user).call
      notice_msg = "Panggilan diakhiri & rangkuman otomatis dibuat. Menunggu ACC Team Lead."
    elsif !@meeting.approved? && !@meeting.summary_ready?
      @meeting.update!(status: "ended", ended_at: @meeting.ended_at || Time.current)
      @meeting.broadcast_summary_refresh!
      notice_msg = "Panggilan video & sesi rapat telah dihentikan."
    else
      @meeting.update!(ended_at: @meeting.ended_at || Time.current)
      @meeting.broadcast_summary_refresh!
      notice_msg = "Sesi panggilan telah dihentikan."
    end

    @project.activity_logs.create!(
      user: current_user,
      meeting: @meeting,
      summary: "#{current_user.full_name} mengakhiri panggilan rapat '#{@meeting.title}' (#{@meeting.room_code})"
    )
    @meeting.meeting_messages.create!(
      user: current_user,
      kind: "system",
      body: "Panggilan video/audio dihentikan oleh #{current_user.full_name}."
    )
    MeetingChannel.broadcast_to(@meeting, {
      type: "call_ended",
      ended_by: current_user.full_name
    })
    @project.broadcast_meeting_refresh!

    redirect_to project_meeting_path(@project, @meeting), notice: notice_msg
  end

  def approve
    result = Meetings::ApplySummary.new(meeting: @meeting, actor: current_user).call
    redirect_to project_meeting_path(@project, @meeting),
      notice: "Rangkuman di-ACC! #{result.applied_count} perubahan otomatis diterapkan ke Kanban Board."
  rescue ArgumentError => e
    redirect_to project_meeting_path(@project, @meeting), alert: e.message
  end

  def reject
    reason = params[:rejection_reason].presence || "Perlu revisi ringkasan sebelum diterapkan ke Kanban."

    Meeting.transaction do
      @meeting.update!(status: "rejected", rejection_reason: reason)
      @project.activity_logs.create!(
        user: current_user,
        meeting: @meeting,
        summary: "#{current_user.full_name} menolak rangkuman '#{@meeting.title}': #{reason}"
      )
      @meeting.meeting_messages.create!(
        user: current_user,
        kind: "system",
        body: "Rangkuman ditolak oleh #{current_user.full_name}: #{reason}"
      )
    end

    @meeting.broadcast_summary_refresh!
    @project.broadcast_meeting_refresh!
    redirect_to project_meeting_path(@project, @meeting), alert: "Rangkuman rapat ditolak. Silakan revisi catatan lalu generate ulang."
  end

  private
    def set_project
      load_authorized_project(:project_id)
    end

    def set_meeting
      @meeting = @project.meetings.find(params[:id])
    end

    def require_lead!
      return if current_user.lead_of?(@project.team)

      respond_to do |format|
        format.json { render json: { error: "Akses ditolak. Hanya Team Lead tim ini yang berhak menyetujui (ACC)." }, status: :forbidden }
        format.html { redirect_to project_meeting_path(@project, @meeting), alert: "Hanya Team Lead tim ini yang dapat menyetujui (ACC) atau menolak rangkuman rapat." }
      end
    end

    def require_moderator!
      return if current_user.lead_of?(@project.team) || @meeting.host_id == current_user.id

      redirect_to project_meeting_path(@project, @meeting), alert: "Hanya Host Rapat atau Team Lead yang dapat mengubah usulan perubahan."
    end

    def require_host!
      return if @meeting.host_id == current_user.id

      redirect_to project_meeting_path(@project, @meeting), alert: "Hanya pembuat room (Host) yang dapat mengakhiri panggilan untuk semua peserta."
    end

    def meeting_params
      params.require(:meeting).permit(:title, :agenda)
    end

    def action_item_params
      params.require(:meeting_action_item).permit(:action_type, :target_task_id, :title, :description, :target_column, :priority, :assignee_id, :due_date)
    end

    def apply_normalized_action_item_params(item)
      attrs = action_item_params.to_h
      mode = params[:item_mode].to_s

      if mode == "create"
        attrs["action_type"] = "create_task"
        attrs["target_task_id"] = nil
      elsif mode == "existing"
        attrs["action_type"] = "update_task" if attrs["action_type"].blank? || attrs["action_type"] == "create_task"
      elsif attrs["action_type"] == "create_task"
        attrs["target_task_id"] = nil
      end

      item.assign_attributes(attrs)

      if item.updates_existing_task?
        target = @project.tasks.find_by(id: item.target_task_id)
        if target.nil?
          item.errors.add(:target_task_id, "wajib dipilih saat memperbarui ticket yang sudah ada")
          return false
        end

        if item.title.blank?
          item.title = "#{item.action_type_label} #{target.code}: #{target.title}".truncate(140)
        end
      end

      true
    end

    def render_summary_panel_turbo_stream
      render turbo_stream: turbo_stream.replace(
        ActionView::RecordIdentifier.dom_id(@meeting, :summary_panel),
        partial: "meetings/summary_panel",
        locals: {
          meeting: @meeting,
          project: @project,
          team_members: @project.team.users.active.ordered_by_name,
          project_tasks: @project.tasks.ordered_for_board
        }
      )
    end
end
