module ApplicationHelper
  MONTHS_ID = %w[Jan Feb Mar Apr Mei Jun Jul Agu Sep Okt Nov Des].freeze
  VALID_THEMES = %w[light dark system].freeze

  def theme_preference
    pref = cookies[:syncboard_theme].to_s
    VALID_THEMES.include?(pref) ? pref : "light"
  end

  def theme_html_class
    theme_preference == "dark" ? "dark" : nil
  end

  def format_date_id(value, include_time: false)
    return nil if value.blank?

    local = value.respond_to?(:in_time_zone) ? value.in_time_zone : value
    formatted = format("%02d %s %04d", local.day, MONTHS_ID[local.month - 1], local.year)
    include_time ? "#{formatted} #{local.strftime('%H:%M')}" : formatted
  end

  def ui_card_class(extra = nil)
    "rounded-xl border border-outline-variant bg-panel text-on-surface shadow-xs #{extra}".strip
  end

  def ui_label_class(extra = nil)
    "block text-xs font-semibold text-on-surface #{extra}".strip
  end

  def ui_input_class(extra = nil)
    "block w-full min-h-[42px] rounded-xl border border-outline bg-input px-3 py-2 text-sm text-on-surface placeholder:text-on-surface-muted focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/30 transition #{extra}".strip
  end

  def ui_btn_primary_class(extra = nil)
    "inline-flex min-h-11 items-center justify-center gap-1.5 rounded-xl bg-primary px-4 py-2 text-sm font-semibold text-on-primary shadow-xs hover:bg-primary-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2 focus-visible:ring-offset-canvas transition cursor-pointer #{extra}".strip
  end

  def ui_btn_secondary_class(extra = nil)
    "inline-flex min-h-11 items-center justify-center gap-1.5 rounded-xl border border-outline bg-panel px-3.5 py-2 text-xs font-semibold text-on-surface hover:bg-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2 focus-visible:ring-offset-canvas transition cursor-pointer #{extra}".strip
  end

  def ui_btn_danger_class(extra = nil)
    "inline-flex min-h-11 items-center justify-center gap-1.5 rounded-xl border border-danger-border bg-danger-soft px-3 py-1.5 text-xs font-semibold text-on-danger-soft hover:bg-danger hover:text-on-danger hover:border-danger focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-danger focus-visible:ring-offset-2 focus-visible:ring-offset-canvas transition cursor-pointer #{extra}".strip
  end

  def task_card_surface_class(task)
    case task.due_status
    when :overdue
      "border-danger-border bg-danger-soft"
    when :approaching
      "border-warning-border bg-warning-soft"
    else
      "border-outline-variant bg-card hover:border-outline"
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
        class: "inline-flex items-center rounded-md border border-danger-border bg-card px-2 py-0.5 font-mono text-[11px] font-semibold text-on-danger-soft"
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
        class: "inline-flex items-center rounded-md border border-warning-border bg-card px-2 py-0.5 font-mono text-[11px] font-semibold text-on-warning-soft"
      )
    else
      content_tag(
        :span,
        "Target #{date_text}",
        class: "font-mono text-[11px] font-medium text-on-surface-muted"
      )
    end
  end

  def action_mode_badge(item)
    if item.creates_new_task?
      content_tag(:span, "Buat Ticket Baru",
        class: "inline-flex items-center rounded-md border border-outline-variant bg-inset px-2 py-0.5 text-[11px] font-semibold text-on-surface-variant")
    else
      content_tag(:span, "Update Ticket Ada",
        class: "inline-flex items-center rounded-md border border-warning-border bg-warning-soft px-2 py-0.5 text-[11px] font-semibold text-on-warning-soft")
    end
  end

  def user_avatar(user, size_class: "w-10 h-10", text_class: "text-sm", lead: nil, team: nil)
    return "" if user.nil?

    if user.avatar.attached?
      image_tag user.avatar,
        alt: user.full_name,
        class: "#{size_class} rounded-xl border border-outline-variant object-cover shrink-0"
    else
      resolved_team = team || (respond_to?(:current_team) ? current_team : nil)
      is_lead = if !lead.nil?
        lead
      elsif resolved_team
        resolved_team.lead?(user)
      else
        user.lead?
      end
      bg_class = is_lead ? "border-primary-border bg-primary-soft text-on-primary-soft" : "border-outline-variant bg-inset text-on-surface-variant"
      content_tag(
        :div,
        user.initials,
        class: "#{size_class} #{bg_class} flex items-center justify-center rounded-xl border font-semibold #{text_class} shrink-0 select-none"
      )
    end
  end

  def material_icon(name, size: 18, extra_class: "", filled: false)
    style = "font-size: #{size}px;"
    style = "#{style} font-variation-settings: 'FILL' 1, 'wght' 400, 'GRAD' 0, 'opsz' 20;" if filled
    content_tag(
      :span,
      name,
      class: "material-symbols-outlined shrink-0 leading-none select-none #{extra_class}".strip,
      style: style,
      aria: { hidden: true }
    )
  end

  def brand_logo(size_class: "h-8 w-8")
    image_tag("/icon.svg?v=2", alt: "SyncBoard", class: "#{size_class} shrink-0 object-contain")
  end

  def sidebar_link_class(path)
    base = "flex min-h-11 sm:min-h-9 items-center gap-2.5 rounded-[8px] px-2.5 py-2 sm:py-1.5 text-[13px] font-medium transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
    if current_page?(path)
      "#{base} border border-outline-variant/80 bg-card text-primary-text font-semibold shadow-2xs"
    else
      "#{base} border border-transparent text-on-surface-variant hover:bg-hover hover:text-on-surface"
    end
  end

  def task_priority_badge(priority)
    value = priority.respond_to?(:priority) ? priority.priority : priority.to_s
    styles = {
      "urgent" => "border-danger-border bg-danger-soft text-on-danger-soft",
      "high" => "border-warning-border bg-warning-soft text-on-warning-soft",
      "medium" => "border-primary-border bg-primary-soft text-on-primary-soft",
      "low" => "border-outline-variant bg-inset text-on-surface-muted"
    }
    label = Task::PRIORITIES.fetch(value, value.humanize)
    content_tag(:span, label, class: "inline-flex items-center rounded-md border px-2 py-0.5 text-[11px] font-semibold #{styles.fetch(value, styles['medium'])}")
  end

  def task_column_badge(column_key)
    key = column_key.to_s
    styles = {
      "todo" => "border-outline-variant bg-inset text-on-surface-variant",
      "in_progress" => "border-outline bg-card text-on-surface",
      "review" => "border-warning-border bg-warning-soft text-on-warning-soft",
      "done" => "border-primary-border bg-primary-soft text-on-primary-soft"
    }
    label = Task::COLUMNS.fetch(key, key.humanize)
    content_tag(:span, label, class: "inline-flex items-center rounded-md border px-2 py-0.5 text-[11px] font-semibold #{styles.fetch(key, styles['todo'])}")
  end

  def meeting_status_badge(meeting)
    styles = {
      "live" => "border-danger-border bg-danger-soft text-on-danger-soft",
      "ended" => "border-outline-variant bg-inset text-on-surface-variant",
      "summary_ready" => "border-warning-border bg-warning-soft text-on-warning-soft",
      "approved" => "border-primary-border bg-primary-soft text-on-primary-soft",
      "rejected" => "border-danger-border bg-danger-soft text-on-danger-soft"
    }
    badge_class = styles.fetch(meeting.status, "border-outline-variant bg-inset text-on-surface-variant")
    content_tag(:span, meeting.status_label, class: "inline-flex items-center rounded-md border px-2.5 py-0.5 text-xs font-semibold #{badge_class}")
  end

  def action_type_badge(action_type)
    styles = {
      "create_task" => "border-outline-variant bg-inset text-on-surface-variant",
      "move_task" => "border-outline-variant bg-column text-on-surface-variant",
      "update_task" => "border-outline bg-card text-on-surface",
      "complete_task" => "border-primary-border bg-primary-soft text-on-primary-soft"
    }
    label = MeetingActionItem::ACTION_TYPES.fetch(action_type, action_type.humanize)
    content_tag(:span, label, class: "inline-flex items-center rounded-md border px-2 py-0.5 text-[11px] font-semibold #{styles.fetch(action_type, styles['create_task'])}")
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
