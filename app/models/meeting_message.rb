class MeetingMessage < ApplicationRecord
  KINDS = {
    "chat" => "Chat",
    "decision" => "Keputusan",
    "note" => "Catatan",
    "system" => "Sistem"
  }.freeze

  belongs_to :meeting
  belongs_to :user

  scope :chronological, -> { order(:created_at, :id) }

  validates :body, presence: true, length: { maximum: 2000 }
  validates :kind, presence: true, inclusion: { in: KINDS.keys }

  after_create_commit :broadcast_message

  def kind_label
    KINDS.fetch(kind, kind.humanize)
  end

  private
    def broadcast_message
      Turbo::StreamsChannel.broadcast_append_to(
        [ meeting, :room ],
        target: ActionView::RecordIdentifier.dom_id(meeting, :messages),
        partial: "meeting_messages/message",
        locals: { message: self }
      )
    end
end
