require "net/http"
require "json"

module Meetings
  class SummaryGenerator
    ACTION_KEYWORDS = /\b(buat\s+task|tambah\s+task|task\s+baru|action\s*item|todo|perlu\s+dibuat|kerjakan|buatkan|implementasi|perbaiki|fix|integrasi|deploy|setup|uji|testing|review)\b/i
    COMPLETE_KEYWORDS = /\b(selesai|kelar|beres|done|tutup|close|closed|rampung|resolved)\b/i
    MOVE_KEYWORDS = /\b(pindah|geser|lanjut|masuk\s+ke|set\s+ke|ubah\s+status|status)\b/i

    def initialize(meeting:, actor:)
      @meeting = meeting
      @actor = actor
      @project = meeting.project
      @team_members = @project.team.users.active.ordered_by_name.to_a
      @project_tasks = @project.tasks.ordered_for_board.to_a
    end

    def call
      payload = generate_with_gemini || generate_locally

      Meeting.transaction do
        @meeting.meeting_action_items.where(applied: false).destroy_all

        payload[:items].each do |item_attrs|
          @meeting.meeting_action_items.create!(item_attrs)
        end

        @meeting.update!(
          summary_text: payload[:summary_text],
          status: "summary_ready",
          rejection_reason: nil
        )
      end

      @meeting.broadcast_summary_refresh!
      @meeting
    end

    private
      def collected_lines
        lines = []
        @meeting.transcript_text.to_s.each_line do |raw_line|
          cleaned = raw_line.strip
          lines << cleaned if cleaned.present?
        end

        @meeting.meeting_messages.chronological.includes(:user).each do |msg|
          next if msg.kind == "system"

          prefix = msg.kind == "decision" ? "[KEPUTUSAN]" : "[#{msg.kind.upcase}]"
          lines << "#{prefix} #{msg.user.full_name}: #{msg.body.strip}"
        end

        lines
      end

      def generate_locally
        lines = collected_lines
        decisions = []
        notes = []
        items = []
        seen_signatures = {}

        lines.each do |line|
          if line.start_with?("[KEPUTUSAN]") || line.match?(/\b(sepakat|disepakati|keputusan|acc)\b/i)
            decisions << clean_line(line)
          elsif line.start_with?("[NOTE]") || line.match?(/\b(catatan|penting|risiko|blocker)\b/i)
            notes << clean_line(line)
          end

          parsed = parse_line_to_action_item(line)
          next unless parsed

          signature = "#{parsed[:action_type]}:#{parsed[:target_task_id]}:#{parsed[:title].downcase}"
          next if seen_signatures[signature]

          seen_signatures[signature] = true
          items << parsed
        end

        if items.empty? && lines.any?
          fallback_title = truncate_title(clean_line(lines.first).sub(/\A[^:]+:\s*/, ""))
          items << {
            action_type: "create_task",
            title: fallback_title.presence || "Tindak lanjut hasil diskusi #{@meeting.title}",
            description: "Dihasilkan dari notulensi rapat #{@meeting.title} oleh #{@actor.full_name}.",
            target_column: "todo",
            priority: "medium",
            assignee_id: detect_assignee(lines.join(" "))&.id,
            selected: true
          }
        end

        summary_sections = []
        summary_sections << "Ringkasan Rapat: #{@meeting.title} (Room #{@meeting.room_code})"
        summary_sections << "Agenda: #{@meeting.agenda}" if @meeting.agenda.present?

        if decisions.any?
          summary_sections << ""
          summary_sections << "Keputusan Utama:"
          decisions.uniq.first(6).each { |d| summary_sections << "- #{d}" }
        end

        if notes.any?
          summary_sections << ""
          summary_sections << "Catatan Diskusi:"
          notes.uniq.first(5).each { |n| summary_sections << "- #{n}" }
        end

        summary_sections << ""
        summary_sections << "Usulan Perubahan Kanban (#{items.size} item menunggu ACC Team Lead):"
        items.each_with_index do |item, index|
          label = MeetingActionItem::ACTION_TYPES[item[:action_type]]
          col_label = Task::COLUMNS[item[:target_column]]
          assignee_name = @team_members.find { |u| u.id == item[:assignee_id] }&.full_name
          assignee_suffix = assignee_name ? " | PIC: #{assignee_name}" : ""
          summary_sections << "#{index + 1}. [#{label}] #{item[:title]} -> #{col_label} (#{item[:priority].upcase}#{assignee_suffix})"
        end

        if lines.empty?
          summary_sections << ""
          summary_sections << "(Belum ada transcript atau catatan chat. Tambahkan catatan rapat lalu generate ulang jika perlu.)"
        end

        {
          summary_text: summary_sections.join("\n"),
          items: items
        }
      end

      def parse_line_to_action_item(line)
        body = clean_line(line)
        referenced_task = find_referenced_task(body)

        if referenced_task
          target_col = detect_column(body)
          if body.match?(COMPLETE_KEYWORDS)
            return {
              action_type: "complete_task",
              target_task_id: referenced_task.id,
              title: "Selesaikan #{referenced_task.code}: #{referenced_task.title}",
              description: "Ditandai selesai saat rapat #{@meeting.title}: #{body}",
              target_column: "done",
              priority: detect_priority(body, default: referenced_task.priority),
              assignee_id: detect_assignee(body)&.id || referenced_task.assignee_id,
              selected: true
            }
          elsif target_col.present? || body.match?(MOVE_KEYWORDS)
            resolved_col = target_col || next_column_for(referenced_task.column_status)
            return {
              action_type: "move_task",
              target_task_id: referenced_task.id,
              title: "Pindahkan #{referenced_task.code} ke #{Task::COLUMNS[resolved_col]}",
              description: "Perpindahan kolom dari diskusi #{@meeting.title}: #{body}",
              target_column: resolved_col,
              priority: detect_priority(body, default: referenced_task.priority),
              assignee_id: detect_assignee(body)&.id || referenced_task.assignee_id,
              selected: true
            }
          else
            return {
              action_type: "update_task",
              target_task_id: referenced_task.id,
              title: "Update #{referenced_task.code}: #{referenced_task.title}",
              description: "Pembaruan dari rapat #{@meeting.title}: #{body}",
              target_column: referenced_task.column_status,
              priority: detect_priority(body, default: referenced_task.priority),
              assignee_id: detect_assignee(body)&.id || referenced_task.assignee_id,
              selected: true
            }
          end
        end

        is_decision_or_note = line.start_with?("[KEPUTUSAN]") || line.start_with?("[NOTE]")
        return nil unless is_decision_or_note || body.match?(ACTION_KEYWORDS)

        cleaned_title = extract_task_title(body)
        return nil if cleaned_title.blank?

        {
          action_type: "create_task",
          title: cleaned_title,
          description: "Diusulkan dalam rapat #{@meeting.title}: #{body}",
          target_column: detect_column(body) || "todo",
          priority: detect_priority(body, default: "medium"),
          assignee_id: detect_assignee(body)&.id,
          selected: true
        }
      end

      def clean_line(line)
        line.sub(/\A\[[^\]]+\]\s*/, "").strip
      end

      def find_referenced_task(text)
        prefix = Regexp.escape(@project.key)
        code_match = text.match(/\b(#{prefix})[\s-]+(\d+)\b/i)
        if code_match
          normalized_code = "#{code_match[1]}-#{code_match[2]}"
          task = @project_tasks.find { |t| t.code.casecmp?(normalized_code) }
          return task if task
        end

        down = text.downcase
        @project_tasks.find do |task|
          task.title.length >= 8 && down.include?(task.title.downcase)
        end
      end

      def detect_column(text)
        down = text.downcase
        return "done" if down.match?(/\b(done|selesai|kelar|beres)\b/)
        return "review" if down.match?(/\b(in\s*review|review|qa|uji\s+coba)\b/)
        return "in_progress" if down.match?(/\b(in\s*progress|dikerjakan|mulai\s+kerjakan|sedang\s+proses)\b/)
        return "todo" if down.match?(/\b(to\s*do|todo|backlog|rencana)\b/)

        nil
      end

      def next_column_for(current_column)
        order = Task::COLUMNS.keys
        idx = order.index(current_column) || 0
        order[[ idx + 1, order.length - 1 ].min]
      end

      def detect_priority(text, default: "medium")
        down = text.downcase
        return "urgent" if down.match?(/\b(urgent|kritis|darurat|segera|asap|blocker)\b/)
        return "high" if down.match?(/\b(high|tinggi|penting|prioritas)\b/)
        return "low" if down.match?(/\b(low|rendah|nanti|opsional)\b/)

        default
      end

      def detect_assignee(text)
        down = text.downcase
        @team_members.find do |member|
          first_name = member.full_name.split(/\s+/).first.to_s.downcase
          down.include?(member.full_name.downcase) || (first_name.length >= 3 && down.match?(/\b#{Regexp.escape(first_name)}\b/))
        end
      end

      def extract_task_title(body)
        title = body.sub(/\A[^:]{2,40}:\s*/, "").strip
        prefix_pattern = /\A(?:tolong|mohon|silakan|kita\s+perlu|perlu|sepakat|disepakati|keputusan|buat\s+task\s+baru|buat\s+task|tambah\s+task\s+baru|tambah\s+task|task\s+baru|action\s*item|todo|untuk|buatkan)\s+/i

        while title.sub!(prefix_pattern, "")
          title.strip!
        end

        title = title.sub(/\.\z/, "").strip
        truncate_title(title.sub(/\A./, &:upcase))
      end

      def truncate_title(str)
        clean = str.to_s.gsub(/\s+/, " ").strip
        return clean if clean.length <= 135

        "#{clean[0, 132].rstrip}..."
      end

      def generate_with_gemini
        api_key = ENV["GEMINI_API_KEY"].presence
        return nil unless api_key

        lines = collected_lines
        return nil if lines.empty?

        existing_tasks_json = @project_tasks.map { |t| { id: t.id, code: t.code, title: t.title, column_status: t.column_status, priority: t.priority } }.to_json
        members_json = @team_members.map { |u| { id: u.id, name: u.full_name, job_title: u.job_title } }.to_json

        prompt = <<~PROMPT
          Kamu adalah asisten rapat tim software SyncBoard. Analisis catatan rapat berikut dan keluarkan JSON valid saja (tanpa markdown) dengan struktur:
          {"summary_text":"string ringkasan bahasa Indonesia","items":[{"action_type":"create_task|move_task|update_task|complete_task","target_task_id":null,"title":"string <= 130 char","description":"string","target_column":"todo|in_progress|review|done","priority":"low|medium|high|urgent","assignee_id":null}]}
          Task proyek saat ini: #{existing_tasks_json}
          Anggota tim: #{members_json}
          Catatan rapat:
          #{lines.join("\n")}
        PROMPT

        uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=#{api_key}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = 5
        http.read_timeout = 12

        request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
        request.body = {
          contents: [ { parts: [ { text: prompt } ] } ],
          generationConfig: { responseMimeType: "application/json", temperature: 0.2 }
        }.to_json

        response = http.request(request)
        return nil unless response.is_a?(Net::HTTPSuccess)

        raw = JSON.parse(response.body).dig("candidates", 0, "content", "parts", 0, "text")
        parsed = JSON.parse(raw.to_s)
        return nil unless parsed["summary_text"].present? && parsed["items"].is_a?(Array)

        valid_task_ids = @project_tasks.map(&:id)
        valid_member_ids = @team_members.map(&:id)

        items = parsed["items"].filter_map do |row|
          action_type = MeetingActionItem::ACTION_TYPES.key?(row["action_type"]) ? row["action_type"] : "create_task"
          target_col = Task::COLUMNS.key?(row["target_column"]) ? row["target_column"] : "todo"
          priority = Task::PRIORITIES.key?(row["priority"]) ? row["priority"] : "medium"
          target_task_id = valid_task_ids.include?(row["target_task_id"]) ? row["target_task_id"] : nil
          assignee_id = valid_member_ids.include?(row["assignee_id"]) ? row["assignee_id"] : nil
          action_type = "create_task" if target_task_id.nil? && action_type != "create_task"

          next if row["title"].blank?

          {
            action_type: action_type,
            target_task_id: target_task_id,
            title: row["title"].to_s.first(135),
            description: row["description"].to_s,
            target_column: target_col,
            priority: priority,
            assignee_id: assignee_id,
            selected: true
          }
        end

        return nil if items.empty?

        { summary_text: parsed["summary_text"].to_s, items: items }
      rescue StandardError
        nil
      end
  end
end
