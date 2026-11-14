module ApplicationHelper
  MONTHS_ID = %w[Jan Feb Mar Apr Mei Jun Jul Agu Sep Okt Nov Des].freeze
  VALID_THEMES = %w[light dark system].freeze

  # Crisp 24x24 inline SVG geometry replacing Google Material Symbols webfont to eliminate FOUT and external font fetches.
  SVG_ICON_PATHS = {
    "add" => "M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2Z",
    "arrow_back" => "M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2Z",
    "arrow_forward" => "M12 4l-1.41 1.41L16.17 11H4v2h12.17l-5.58 5.59L12 20l8-8Z",
    "auto_awesome" => "M19 9l1.25-2.75L23 5l-2.75-1.25L19 1l-1.25 2.75L15 5l2.75 1.25L19 9Zm-7.5.5L9 4 6.5 9.5 1 12l5.5 2.5L9 20l2.5-5.5L17 12l-5.5-2.5ZM19 15l-1.25 2.75L15 19l2.75 1.25L19 23l1.25-2.75L23 19l-2.75-1.25L19 15Z",
    "call" => "M20.01 15.38c-1.23 0-2.42-.2-3.53-.56a.977.977 0 0 0-1.01.24l-1.57 1.97c-2.83-1.35-5.48-3.9-6.89-6.83l1.95-1.66c.27-.28.35-.67.24-1.02-.37-1.11-.56-2.3-.56-3.53 0-.54-.45-.99-.99-.99H4.19C3.65 3 3 3.24 3 3.99 3 13.28 10.73 21 20.01 21c.71 0 .99-.63.99-1.18v-3.45c0-.54-.45-.99-.99-.99Z",
    "call_end" => "M12 9c-1.6 0-3.15.25-4.6.72v3.1c0 .39-.23.74-.56.9-.98.49-1.87 1.12-2.66 1.85-.18.18-.43.28-.7.28-.28 0-.53-.11-.71-.29L.29 13.08a.956.956 0 0 1-.29-.7c0-.28.11-.53.29-.71C3.34 8.78 7.46 7 12 7s8.66 1.78 11.71 4.67c.18.18.29.43.29.71 0 .28-.11.53-.29.71l-2.48 2.48c-.18.18-.43.29-.71.29-.27 0-.52-.11-.7-.28a11.27 11.27 0 0 0-2.67-1.85.996.996 0 0 1-.56-.9v-3.1C15.15 9.25 13.6 9 12 9Z",
    "close" => "M19 6.41 17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12Z",
    "closed_caption" => "M19 4H5a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h14c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2Zm0 14H5V6h14v12Zm-8-7H9.5v-.5h-2v3h2V13H11v1c0 .55-.45 1-1 1H7c-.55 0-1-.45-1-1v-4c0-.55.45-1 1-1h3c.55 0 1 .45 1 1v1Zm7 0h-1.5v-.5h-2v3h2V13H18v1c0 .55-.45 1-1 1h-3c-.55 0-1-.45-1-1v-4c0-.55.45-1 1-1h3c.55 0 1 .45 1 1v1Z",
    "contrast" => "M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2Zm0 18V4c4.41 0 8 3.59 8 8s-3.59 8-8 8Z",
    "dark_mode" => "M12 3a9 9 0 1 0 9 9c0-.46-.04-.92-.1-1.36a5.389 5.389 0 0 1-4.4 2.26 5.403 5.403 0 0 1-3.14-9.8c-.44-.06-.9-.1-1.36-.1Z",
    "flip" => "M15 21h2v-2h-2v2Zm4-12h2V7h-2v2ZM3 5v14c0 1.1.9 2 2 2h4v-2H5V5h4V3H5c-1.1 0-2 .9-2 2Zm16-2v2h2c0-1.1-.9-2-2-2Zm-8 20h2V1h-2v22Zm8-6h2v-2h-2v2ZM15 5h2V3h-2v2Zm4 8h2v-2h-2v2Zm0 8c1.1 0 2-.9 2-2h-2v2Z",
    "graphic_eq" => "M7 18h2V6H7v12Zm4 4h2V2h-2v20Zm-8-8h2v-4H3v4Zm12 4h2V6h-2v12Zm4-8v4h2v-4h-2Z",
    "grid_view" => "M3 3v8h8V3H3Zm6 6H5V5h4v4Zm-6 4v8h8v-8H3Zm6 6H5v-4h4v4Zm4-16v8h8V3h-8Zm6 6h-4V5h4v4Zm-6 4v8h8v-8h-8Zm6 6h-4v-4h4v4Z",
    "group_add" => "M15 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4Zm0-6a2 2 0 1 1 0 4 2 2 0 0 1 0-4Zm0 8c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4Zm-6 4c.22-.72 3.31-2 6-2 2.7 0 5.8 1.29 6 2H9Zm-3-3v-3h3v-2H6V7H4v3H1v2h3v3h2Z",
    "groups" => "M12 12.75c1.63 0 3.07.39 4.24.9 1.08.48 1.76 1.56 1.76 2.73V18H6v-1.61c0-1.18.68-2.26 1.76-2.73 1.17-.52 2.61-.91 4.24-.91ZM4 13c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2Zm1.13 1.1c-.37-.06-.74-.1-1.13-.1-.99 0-1.93.21-2.78.58A2.01 2.01 0 0 0 0 16.43V18h4.5v-1.61c0-.83.23-1.61.63-2.29ZM20 13c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2Zm4 3.43c0-.81-.48-1.53-1.22-1.85-.85-.37-1.79-.58-2.78-.58-.39 0-.76.04-1.13.1.4.68.63 1.46.63 2.29V18H24v-1.57ZM12 6c1.66 0 3 1.34 3 3s-1.34 3-3 3-3-1.34-3-3 1.34-3 3-3Z",
    "light_mode" => "M12 7a5 5 0 1 0 0 10 5 5 0 0 0 0-10Zm0 8a3 3 0 1 1 0-6 3 3 0 0 1 0 6Zm0-13a1 1 0 0 1 1 1v2a1 1 0 1 1-2 0V3a1 1 0 0 1 1-1Zm0 17a1 1 0 0 1 1 1v2a1 1 0 1 1-2 0v-2a1 1 0 0 1 1-1Zm9-8a1 1 0 0 1-1 1h-2a1 1 0 1 1 0-2h2a1 1 0 0 1 1 1ZM7 12a1 1 0 0 1-1 1H4a1 1 0 1 1 0-2h2a1 1 0 0 1 1 1Zm12.07-7.07a1 1 0 0 1 0 1.41l-1.41 1.42a1 1 0 1 1-1.42-1.42l1.42-1.41a1 1 0 0 1 1.41 0ZM7.76 16.24a1 1 0 0 1 0 1.42l-1.42 1.41a1 1 0 0 1-1.41-1.41l1.41-1.42a1 1 0 0 1 1.42 0Zm9.9 1.42a1 1 0 0 1-1.42 0l-1.41-1.42a1 1 0 0 1 1.41-1.41l1.42 1.41a1 1 0 0 1 0 1.42ZM6.34 7.76a1 1 0 0 1-1.41-1.42l1.41-1.41a1 1 0 0 1 1.42 1.41L6.34 7.76Z",
    "logout" => "M17 7l-1.41 1.41L18.17 11H8v2h10.17l-2.58 2.58L17 17l5-5-5-5ZM4 5h8V3H4c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h8v-2H4V5Z",
    "manage_accounts" => "M10 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8Zm0-6a2 2 0 1 1 0 4 2 2 0 0 1 0-4Zm0 8c-2.67 0-8 1.34-8 4v2h10v-2H4.2c.65-.83 3.41-2 5.8-2 1.07 0 2.26.2 3.31.5l1.03-1.78C13.06 14.27 11.53 14 10 14Zm10.78-.22-.97.56c-.18-.11-.38-.19-.59-.25L19 13h-1.5l-.22 1.09c-.21.06-.41.14-.59.25l-.97-.56-.75 1.3.78.66c-.02.11-.03.22-.03.33 0 .11.01.22.03.33l-.78.66.75 1.3.97-.56c.18.11.38.19.59.25l.22 1.09H19l.22-1.09c.21-.06.41-.14.59-.25l.97.56.75-1.3-.78-.66c.02-.11.03-.22.03-.33 0-.11-.01-.22-.03-.33l.78-.66-.75-1.3Zm-2.53 3.54c-.69 0-1.25-.56-1.25-1.25s.56-1.25 1.25-1.25 1.25.56 1.25 1.25-.56 1.25-1.25 1.25Z",
    "menu" => "M3 18h18v-2H3v2Zm0-5h18v-2H3v2Zm0-7v2h18V6H3Z",
    "mic" => "M12 14c1.66 0 3-1.34 3-3V5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3Zm-1-9a1 1 0 0 1 2 0v6a1 1 0 0 1-2 0V5Zm6 6c0 2.76-2.24 5-5 5s-5-2.24-5-5H5c0 3.53 2.61 6.43 6 6.92V21h2v-3.08c3.39-.49 6-3.39 6-6.92h-2Z",
    "mic_off" => "M19 11h-1.7c0 .74-.16 1.43-.43 2.05l1.23 1.23c.56-.98.9-2.09.9-3.28Zm-4.02.17c0-.06.02-.11.02-.17V5c0-1.66-1.34-3-3-3S9 3.34 9 5v.18l5.98 5.99ZM4.27 3 3 4.27l6.01 6.01V11c0 1.66 1.33 3 2.99 3 .22 0 .44-.03.65-.08l1.66 1.66c-.71.33-1.5.52-2.31.52-2.76 0-5.3-2.1-5.3-5.1H5c0 3.41 2.72 6.23 6 6.72V21h2v-3.28c.91-.13 1.77-.45 2.54-.9L19.73 21 21 19.73 4.27 3Z",
    "present_to_all" => "M21 3H3c-1.11 0-2 .89-2 2v14c0 1.11.89 2 2 2h18c1.11 0 2-.89 2-2V5c0-1.11-.89-2-2-2Zm0 16.02H3V4.98h18v14.04ZM10 12H8l4-4 4 4h-2v4h-4v-4Z",
    "search" => "M15.5 14h-.79l-.28-.27A6.47 6.47 0 0 0 16 9.5 6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5Zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14Z",
    "settings" => "M19.14 12.94c.04-.3.06-.61.06-.94s-.02-.64-.07-.94l2.03-1.58a.49.49 0 0 0 .12-.61l-1.92-3.32a.49.49 0 0 0-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54a.48.48 0 0 0-.48-.41h-3.84a.48.48 0 0 0-.48.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96a.49.49 0 0 0-.59.22L2.74 8.87a.48.48 0 0 0 .12.61l2.03 1.58c-.05.3-.09.63-.09.94s.02.64.07.94l-2.03 1.58a.49.49 0 0 0-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58ZM12 15.6A3.6 3.6 0 1 1 12 8.4a3.6 3.6 0 0 1 0 7.2Z",
    "stop_screen_share" => "M21 3H3c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2Zm0 16H3V5h18v14ZM9.41 15.95 12 13.36l2.59 2.59L16 14.54l-2.59-2.59L16 9.36l-1.41-1.41L12 10.54 9.41 7.95 8 9.36l2.59 2.59L8 14.54l1.41 1.41Z",
    "task_alt" => "M22 5.18 10.59 16.6l-4.24-4.24 1.41-1.41 2.83 2.83 10-10L22 5.18Zm-2.21 5.04c.13.57.21 1.17.21 1.78 0 4.42-3.58 8-8 8s-8-3.58-8-8 3.58-8 8-8c1.58 0 3.04.46 4.28 1.25l1.44-1.44A9.9 9.9 0 0 0 12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10c0-1.19-.22-2.33-.6-3.39l-1.61 1.61Z",
    "unfold_more" => "M12 5.83 15.17 9l1.41-1.41L12 3 7.41 7.59 8.83 9 12 5.83Zm0 12.34L8.83 15l-1.41 1.41L12 21l4.59-4.59L15.17 15 12 18.17Z",
    "videocam" => "M17 10.5V7c0-.55-.45-1-1-1H4c-.55 0-1 .45-1 1v10c0 .55.45 1 1 1h12c.55 0 1-.45 1-1v-3.5l4 4v-11l-4 4Z",
    "videocam_off" => "M21 6.5l-4 4V7c0-.55-.45-1-1-1H9.82L21 17.18V6.5ZM3.27 2 2 3.27 4.73 6H4c-.55 0-1 .45-1 1v10c0 .55.45 1 1 1h12c.21 0 .39-.08.54-.18L19.73 21 21 19.73 3.27 2Z"
  }.freeze
  DEFAULT_ICON_PATH = "M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20Zm0 15a1.25 1.25 0 1 1 0-2.5 1.25 1.25 0 0 1 0 2.5Zm1-4.5h-2V7h2v5.5Z".freeze

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
    _ = filled
    path_d = SVG_ICON_PATHS.fetch(name.to_s, DEFAULT_ICON_PATH)
    svg_ns = "http://www.w3.org/2000/svg"
    tag.svg(
      tag.path(d: path_d),
      xmlns: svg_ns,
      viewBox: "0 0 24 24",
      width: size,
      height: size,
      fill: "currentColor",
      class: "shrink-0 inline-block #{extra_class}".strip,
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
