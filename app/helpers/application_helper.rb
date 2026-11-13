module ApplicationHelper
  MONTHS_ID = %w[Jan Feb Mar Apr Mei Jun Jul Agu Sep Okt Nov Des].freeze

  def format_date_id(value, include_time: false)
    return nil if value.blank?

    local = value.respond_to?(:in_time_zone) ? value.in_time_zone : value
    formatted = format("%02d %s %04d", local.day, MONTHS_ID[local.month - 1], local.year)
    include_time ? "#{formatted} #{local.strftime('%H:%M')}" : formatted
  end

  def task_card_surface_class(task)
    case task.due_status
    when :overdue
      "border-rose-200 bg-rose-50/75 hover:border-rose-300"
    when :approaching
      "border-amber-200 bg-amber-50/75 hover:border-amber-300"
    else
      "border-slate-200 bg-white hover:border-indigo-300"
    end
  end

  def task_due_badge(task)
    return nil if task.due_date.blank?

    date_text = format_date_id(task.due_date)
    days_left = task.days_until_due

    case task.due_status
    when :overdue
      content_tag(
        :span,
        "Target #{date_text} · Terlewati",
        class: "inline-flex items-center gap-1 rounded-md bg-rose-100/80 px-2 py-0.5 text-[10px] font-semibold text-rose-800"
      )
    when :approaching
      hint = case days_left
      when 0 then "Hari ini"
      when 1 then "Besok"
      else "#{days_left} hari lagi"
      end
      content_tag(
        :span,
        "Target #{date_text} · #{hint}",
        class: "inline-flex items-center gap-1 rounded-md bg-amber-100/80 px-2 py-0.5 text-[10px] font-semibold text-amber-900"
      )
    else
      content_tag(
        :span,
        "Target #{date_text}",
        class: "text-[11px] font-medium text-slate-700"
      )
    end
  end

  def action_mode_badge(item)
    if item.creates_new_task?
      content_tag(:span, "Buat Ticket Baru",
        class: "inline-flex items-center rounded-md bg-indigo-50 px-2 py-0.5 text-[10px] font-bold text-indigo-800 ring-1 ring-inset ring-indigo-600/20")
    else
      content_tag(:span, "Update Ticket Ada",
        class: "inline-flex items-center rounded-md bg-amber-50 px-2 py-0.5 text-[10px] font-bold text-amber-900 ring-1 ring-inset ring-amber-600/20")
    end
  end

  def user_avatar(user, size_class: "w-10 h-10", text_class: "text-sm", lead: nil, team: nil)
    return "" if user.nil?

    if user.avatar.attached?
      image_tag user.avatar,
        alt: user.full_name,
        class: "#{size_class} rounded-full object-cover ring-2 ring-slate-200/80 shrink-0"
    else
      resolved_team = team || (respond_to?(:current_team) ? current_team : nil)
      is_lead = if !lead.nil?
        lead
      elsif resolved_team
        resolved_team.lead?(user)
      else
        user.lead?
      end
      bg_class = is_lead ? "bg-indigo-600 text-white" : "bg-sky-600 text-white"
      content_tag(
        :div,
        user.initials,
        class: "#{size_class} #{bg_class} rounded-full flex items-center justify-center font-bold #{text_class} shrink-0 select-none"
      )
    end
  end

  def sidebar_link_class(path)
    base = "flex items-center gap-3 rounded-xl px-3.5 py-2.5 text-sm font-medium transition"
    if current_page?(path)
      "#{base} bg-indigo-600 text-white shadow-xs"
    else
      "#{base} text-slate-300 hover:bg-slate-800 hover:text-white"
    end
  end

  def task_priority_badge(priority)
    value = priority.respond_to?(:priority) ? priority.priority : priority.to_s
    styles = {
      "urgent" => "bg-rose-50 text-rose-700 ring-rose-600/20",
      "high" => "bg-amber-50 text-amber-700 ring-amber-600/20",
      "medium" => "bg-sky-50 text-sky-700 ring-sky-600/20",
      "low" => "bg-slate-100 text-slate-600 ring-slate-500/20"
    }
    label = Task::PRIORITIES.fetch(value, value.humanize)
    content_tag(:span, label, class: "inline-flex items-center rounded-md px-2 py-0.5 text-[11px] font-semibold ring-1 ring-inset #{styles.fetch(value, styles['medium'])}")
  end

  def task_column_badge(column_key)
    key = column_key.to_s
    styles = {
      "todo" => "bg-slate-100 text-slate-700 ring-slate-500/20",
      "in_progress" => "bg-indigo-50 text-indigo-700 ring-indigo-600/20",
      "review" => "bg-amber-50 text-amber-700 ring-amber-600/20",
      "done" => "bg-emerald-50 text-emerald-700 ring-emerald-600/20"
    }
    label = Task::COLUMNS.fetch(key, key.humanize)
    content_tag(:span, label, class: "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold ring-1 ring-inset #{styles.fetch(key, styles['todo'])}")
  end

  def meeting_status_badge(meeting)
    styles = {
      "live" => "bg-rose-50 text-rose-700 ring-rose-600/20",
      "ended" => "bg-slate-100 text-slate-700 ring-slate-500/20",
      "summary_ready" => "bg-amber-50 text-amber-700 ring-amber-600/20",
      "approved" => "bg-emerald-50 text-emerald-700 ring-emerald-600/20",
      "rejected" => "bg-slate-100 text-slate-700 ring-slate-500/20"
    }
    badge_class = styles.fetch(meeting.status, "bg-slate-100 text-slate-700 ring-slate-500/20")
    content_tag(:span, meeting.status_label, class: "inline-flex items-center gap-1.5 rounded-full px-2.5 py-0.5 text-xs font-semibold ring-1 ring-inset #{badge_class}")
  end

  def action_type_badge(action_type)
    styles = {
      "create_task" => "bg-indigo-50 text-indigo-700 ring-indigo-600/20",
      "move_task" => "bg-sky-50 text-sky-700 ring-sky-600/20",
      "update_task" => "bg-violet-50 text-violet-700 ring-violet-600/20",
      "complete_task" => "bg-emerald-50 text-emerald-700 ring-emerald-600/20"
    }
    label = MeetingActionItem::ACTION_TYPES.fetch(action_type, action_type.humanize)
    content_tag(:span, label, class: "inline-flex items-center rounded-md px-2 py-0.5 text-[11px] font-semibold ring-1 ring-inset #{styles.fetch(action_type, styles['create_task'])}")
  end

  def greeting_text
    hour = Time.current.hour
    case hour
    when 4..10 then "Selamat Pagi"
    when 11..14 then "Selamat Siang"
    when 15..17 then "Selamat Sore"
    else "Selamat Malam"
    end
  end

  def webrtc_ice_servers
    if ENV["WEBRTC_ICE_SERVERS_JSON"].present?
      parsed = JSON.parse(ENV["WEBRTC_ICE_SERVERS_JSON"])
      return parsed if parsed.is_a?(Array) && parsed.any?
    end

    servers = [
      { urls: "stun:stun.l.google.com:19302" },
      { urls: "stun:stun1.l.google.com:19302" },
      { urls: "stun:stun.cloudflare.com:3478" }
    ]

    if ENV["TURN_URL"].present?
      turn_entry = { urls: ENV["TURN_URL"] }
      turn_entry[:username] = ENV["TURN_USERNAME"] if ENV["TURN_USERNAME"].present?
      turn_entry[:credential] = ENV["TURN_CREDENTIAL"] if ENV["TURN_CREDENTIAL"].present?
      servers << turn_entry
    end

    servers
  rescue JSON::ParserError
    [
      { urls: "stun:stun.l.google.com:19302" },
      { urls: "stun:stun1.l.google.com:19302" }
    ]
  end
end
