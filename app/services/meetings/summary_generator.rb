# frozen_string_literal: true

module Meetings
  class SummaryGenerator
    Entry = Struct.new(:speaker, :raw_text, :text, :tag, :source, keyword_init: true)

    EXPLICIT_TAG_REGEX = /\A\[(KEPUTUSAN|DECISION|AKSI|ACTION|TODO|TASK|BLOCKER|RISIKO|KENDALA|POIN|CATATAN|NOTE)\]\s*/i
    SPEAKER_PREFIX_REGEX = /\A([A-Za-z][A-Za-z0-9 ._-]{0,40}):\s+(.+)\z/
    LEADING_FILLER_REGEX = /\A(?:oke+|ok+|sip+|siap+|nah+|jadi+|sebenernya|sebenarnya|kalau menurut\s+\w+|menurutku|menurut saya|kayaknya|btw|by the way|intinya|gini|begini|oh ya|eh+|uh+|hmm+|izin info|permisi|halo guys|teman-teman|guys)\s*[,:-]?\s*/i

    NOISE_EXACT_WORDS = %w[
      halo hai hi hey pagi siang sore malam assalamualaikum waalaikumsalam
      tes test oke ok sip siap siapp mantap nice aman masuk jelas kedengeran
      wkwk wkwkwk haha hahaha hehe thank you thanks makasih terimakasih
      bye dadah bentar tunggu sabar loading lag cek sound mic
    ].freeze

    NOISE_PHRASES = [
      /\Ates(?:t)?\s+(?:suara|mic|audio|kamera|video)/i,
      /\Asuara(?:nya)?\s+(?:masuk|jelas|kedengeran)/i,
      /\A(?:layar|screen)\s+(?:udah|sudah)?\s*(?:kelihatan|muncul)/i,
      /\A(?:izin|maaf)\s+(?:share screen|telat|toilet|mute)/i,
      /\Aputus[- ]?putus/i
    ].freeze

    DECISION_PATTERN = /(?:\b(?:sepakat|disepakati|diputuskan|keputusan|setuju|final(?:nya)?|(?:sudah|udah|jadi)\s+fix|deal|agreed|decided|resmi(?:nya)?)\b|\b(?:pakai|gunakan|pilih|lanjutkan dengan)\b.+\b(?:saja|aja)\b)/i
    BLOCKER_PATTERN = /\b(?:blocker|kendala|terhambat|mentok|stuck|bottleneck|risiko|risk|hambatan|masalah berat|timeout|error|bug|gagal|delay|tertunda|belum bisa|menunggu pihak)\b/i
    ACTION_COMMAND_PATTERN = /\b(?:buat(?:kan)?|bikin(?:kan)?|tambah(?:kan)?|create|add|new)\s+(?:kan\s+)?task(?:\s+baru)?\b/i
    DELIVERY_VERB_PATTERN = /\b(?:buat|bikin|fix|perbaiki|rapihin|rapikan|cek|periksa|investigasi|migrasi|integrasi|pasang|setup|konfigurasi|update|perbarui|refactor|hapus|deploy|rilis|uji|testing|test|tulis|dokumentasi|follow[- ]?up|kirim|siapkan|optimasi|hubungi|koordinasi|selesaikan|tutup|review|handle|kerjakan|kerjain)\b/i
    COMMITMENT_PATTERN = /(?:\b(?:tolong|mohon|minta|harus|perlu|wajib|akan|bakal)\b.*#{DELIVERY_VERB_PATTERN.source}|\b(?:saya|aku|gw|gue)\s+(?:akan|mau|bakal|lanjut)\s+#{DELIVERY_VERB_PATTERN.source})/i

    STOPWORDS = %w[
      yang dan di ke dari ini itu untuk dengan pada adalah ada kita kami saya aku gw gue kamu kalian mereka
      nya ya ga gak nggak tidak bisa sudah udah lagi juga kalau jika karena supaya agar biar atau tapi namun
      saat ketika dalam oleh tentang sebagai seperti masih akan mau perlu harus
      the and for that this with from into onto your our you we they are was were have has had can will should
      just only also about very more less
    ].freeze

    PRIORITY_PATTERNS = {
      "urgent" => /\b(?:urgent|kritis|darurat|segera|asap|p0)\b/i,
      "high" => /\b(?:high|tinggi|prioritas utama|penting|p1)\b/i,
      "low" => /\b(?:low|rendah|santai|nanti|p3)\b/i
    }.freeze

    COLUMN_PATTERNS = {
      "done" => /\b(?:done|selesai|kelar|beres|closed|complete|completed)\b/i,
      "review" => /\b(?:in review|review|qa|verifikasi|uji|staging)\b/i,
      "in_progress" => /\b(?:in progress|sedang dikerjakan|dikerjakan|progress|wip|kerjain)\b/i,
      "todo" => /\b(?:todo|to do|backlog|antrian|rencana)\b/i
    }.freeze

    INDONESIAN_MONTHS = {
      "jan" => 1, "januari" => 1, "january" => 1,
      "feb" => 2, "februari" => 2, "february" => 2,
      "mar" => 3, "maret" => 3, "march" => 3,
      "apr" => 4, "april" => 4,
      "mei" => 5, "may" => 5,
      "jun" => 6, "juni" => 6, "june" => 6,
      "jul" => 7, "juli" => 7, "july" => 7,
      "agu" => 8, "agustus" => 8, "aug" => 8, "august" => 8,
      "sep" => 9, "september" => 9,
      "okt" => 10, "oktober" => 10, "oct" => 10, "october" => 10,
      "nov" => 11, "november" => 11,
      "des" => 12, "desember" => 12, "dec" => 12, "december" => 12
    }.freeze

    WEEKDAYS = {
      "minggu" => 0, "sunday" => 0,
      "senin" => 1, "monday" => 1,
      "selasa" => 2, "tuesday" => 2,
      "rabu" => 3, "wednesday" => 3,
      "kamis" => 4, "thursday" => 4,
      "jumat" => 5, "jum'at" => 5, "friday" => 5,
      "sabtu" => 6, "saturday" => 6
    }.freeze

    def initialize(meeting:, actor: nil)
      @meeting = meeting
      @actor = actor
      @project = meeting.project
      @tasks = @project.tasks.includes(:assignee).ordered_for_board.to_a
      @team_members = @project.team.users.active.ordered_by_name.to_a
    end

    def call
      entries = clean_and_deduplicate_entries(collect_entries)
      actions = extract_action_items(entries)
      summary = build_fathom_summary(entries, actions)

      ActiveRecord::Base.transaction do
        @meeting.meeting_action_items.where(applied: false).destroy_all
        actions.each do |attrs|
          @meeting.meeting_action_items.create!(attrs)
        end

        @meeting.update!(
          summary_text: summary,
          status: "summary_ready",
          rejection_reason: nil
        )
      end

      @meeting.broadcast_summary_refresh!
      @meeting
    end

    private

      def collect_entries
        collected = []

        @meeting.transcript_text.to_s.each_line do |raw_line|
          line = raw_line.to_s.strip
          next if line.blank?

          speaker, body, line_tag = parse_line_metadata(line)
          split_into_sentences(body).each do |sentence|
            sentence_speaker, sentence_body, sentence_tag = parse_line_metadata(sentence)
            final_speaker = sentence_speaker || speaker
            final_tag = sentence_tag || line_tag || infer_tag(sentence_body)
            distilled = distill_core_text(sentence_body)
            next if distilled.blank?

            collected << Entry.new(
              speaker: final_speaker,
              raw_text: sentence_body,
              text: distilled,
              tag: final_tag,
              source: :transcript
            )
          end
        end

        @meeting.meeting_messages.where.not(kind: "system").includes(:user).order(:created_at, :id).each do |message|
          body = message.body.to_s.strip
          next if body.blank?

          explicit_kind = message_kind_to_tag(message.kind)
          split_into_sentences(body).each do |sentence|
            _inline_speaker, sentence_body, inline_tag = parse_line_metadata(sentence)
            final_tag = inline_tag || explicit_kind || infer_tag(sentence_body)
            distilled = distill_core_text(sentence_body)
            next if distilled.blank?

            collected << Entry.new(
              speaker: message.user&.full_name,
              raw_text: sentence_body,
              text: distilled,
              tag: final_tag,
              source: message.kind.to_sym
            )
          end
        end

        collected
      end

      def parse_line_metadata(line)
        remaining = line.to_s.strip
        tag = nil

        if (match = remaining.match(EXPLICIT_TAG_REGEX))
          tag = normalize_explicit_tag(match[1])
          remaining = remaining[match[0].length..].to_s.strip
        end

        speaker = nil
        if (speaker_match = remaining.match(SPEAKER_PREFIX_REGEX))
          candidate = speaker_match[1].strip
          unless candidate.match?(/\Ahttps?\z/i)
            speaker = candidate
            remaining = speaker_match[2].strip
          end
        end

        if tag.nil? && (nested_tag = remaining.match(EXPLICIT_TAG_REGEX))
          tag = normalize_explicit_tag(nested_tag[1])
          remaining = remaining[nested_tag[0].length..].to_s.strip
        end

        [ speaker, remaining, tag ]
      end

      def normalize_explicit_tag(label)
        case label.upcase
        when "KEPUTUSAN", "DECISION" then :decision
        when "AKSI", "ACTION", "TODO", "TASK" then :action
        when "BLOCKER", "RISIKO", "KENDALA" then :blocker
        else :note
        end
      end

      def message_kind_to_tag(kind)
        case kind.to_s
        when "decision" then :decision
        when "note" then :note
        else nil
        end
      end

      def split_into_sentences(text)
        cleaned = text.to_s.gsub(/\s+/, " ").strip
        return [] if cleaned.blank?

        # Keep task codes / decimals intact while breaking multi-sentence STT blocks cleanly.
        parts = cleaned.split(/(?<=[.!?])\s+(?=[A-Z0-9\["'])/)
        parts.map(&:strip).reject(&:blank?)
      end

      def distill_core_text(text)
        result = text.to_s.strip
        3.times do
          updated = result.sub(LEADING_FILLER_REGEX, "").strip
          break if updated == result

          result = updated
        end
        result.gsub(/\s+/, " ").strip
      end

      def infer_tag(text)
        return :decision if text.match?(DECISION_PATTERN)
        return :action if action_candidate?(text)
        return :blocker if text.match?(BLOCKER_PATTERN)

        :point
      end

      def clean_and_deduplicate_entries(entries)
        filtered = entries.reject { |entry| noise_entry?(entry) }
        deduped = []

        filtered.each do |entry|
          if deduped.any? && stt_prefix_extension?(deduped.last, entry)
            deduped[-1] = entry
            next
          end

          duplicate = deduped.find { |existing| similar_entries?(existing, entry) }
          if duplicate
            upgrade_existing_entry(duplicate, entry)
            next
          end

          deduped << entry
        end

        deduped
      end

      def noise_entry?(entry)
        return false if %i[decision blocker action].include?(entry.tag) && entry.text.length >= 8
        return false if find_task_match(entry.raw_text).present?

        normalized = normalize_tokens(entry.text)
        return true if NOISE_PHRASES.any? { |pattern| entry.text.match?(pattern) }

        raw_words = entry.text.downcase.gsub(/[^a-z0-9\s]/, " ").split
        return true if raw_words.all? { |word| NOISE_EXACT_WORDS.include?(word) }

        meaningful = normalized - STOPWORDS
        meaningful.size < 2 && raw_words.size < 4
      end

      def stt_prefix_extension?(previous, current)
        return false unless previous.speaker.present? && previous.speaker == current.speaker

        prev_norm = normalize_sentence(previous.text)
        curr_norm = normalize_sentence(current.text)
        curr_norm.start_with?(prev_norm) && curr_norm.length > prev_norm.length
      end

      def similar_entries?(left, right)
        left_norm = normalize_sentence(left.text)
        right_norm = normalize_sentence(right.text)
        return true if left_norm == right_norm

        left_tokens = meaningful_tokens(left.text)
        right_tokens = meaningful_tokens(right.text)
        return false if left_tokens.empty? || right_tokens.empty?

        intersection = (left_tokens & right_tokens).size.to_f
        union = (left_tokens | right_tokens).size.to_f
        (intersection / union) >= 0.72
      end

      def upgrade_existing_entry(existing, incoming)
        priority = { decision: 4, blocker: 3, action: 2, note: 1, point: 0 }
        existing.tag = incoming.tag if priority.fetch(incoming.tag, 0) > priority.fetch(existing.tag, 0)
        if incoming.text.length > existing.text.length
          existing.text = incoming.text
          existing.raw_text = incoming.raw_text
        end
      end

      def normalize_sentence(text)
        text.to_s.downcase.gsub(/[^a-z0-9\s]/, " ").gsub(/\s+/, " ").strip
      end

      def normalize_tokens(text)
        normalize_sentence(text).split
      end

      def meaningful_tokens(text)
        normalize_tokens(text).reject { |token| token.length < 2 || STOPWORDS.include?(token) }.uniq
      end

      def action_candidate?(text)
        return true if find_task_match(text).present? && (text.match?(COLUMN_PATTERNS["done"]) || text.match?(/\b(?:pindah|move|geser|ubah|ganti|ke\s+(?:todo|in progress|progress|in review|review|done)|priorit(?:as|y)|assign|deadline)\b/i))
        return true if text.match?(ACTION_COMMAND_PATTERN)

        has_concrete_commitment?(text)
      end

      def has_concrete_commitment?(text)
        return true if text.match?(COMMITMENT_PATTERN)

        member_action = member_name_tokens.any? do |name|
          text.match?(/\b#{Regexp.escape(name)}\b\s+(?:akan|perlu|harus|tolong|handle|kerjain|mengerjakan)\b/i)
        end
        return true if member_action

        false
      end

      def member_name_tokens
        @member_name_tokens ||= @team_members.flat_map do |user|
          parts = user.full_name.to_s.downcase.split(/\s+/)
          [ user.full_name.to_s.downcase, parts.first ].compact.select { |name| name.length >= 2 }
        end.uniq
      end

      def extract_action_items(entries)
        applied_signatures = @meeting.meeting_action_items.where(applied: true).pluck(:action_type, :target_task_id, :title).map do |type, task_id, title|
          [ type, task_id, normalize_sentence(title) ]
        end

        items = []
        seen_signatures = Set.new(applied_signatures)

        entries.each do |entry|
          candidate = build_action_item(entry)
          next unless candidate

          signature = [ candidate[:action_type], candidate[:target_task_id], normalize_sentence(candidate[:title]) ]
          next if seen_signatures.include?(signature)

          seen_signatures << signature
          items << candidate
        end

        items
      end

      def build_action_item(entry)
        text = entry.raw_text.to_s.strip
        matched_task = find_task_match(text)

        if matched_task
          build_existing_task_action(matched_task, text, entry.speaker)
        elsif entry.tag == :action || text.match?(ACTION_COMMAND_PATTERN) || has_concrete_commitment?(text)
          build_new_task_action(entry)
        end
      end

      def find_task_match(text)
        code_match = @tasks.find do |task|
          text.match?(/\b#{Regexp.escape(task.code)}\b/i)
        end
        return code_match if code_match

        nil
      end

      def build_existing_task_action(task, text, speaker)
        target_column = detect_column(text)
        priority = detect_priority(text)
        assignee = detect_assignee(text, speaker: speaker, fallback_to_speaker: false)
        due_date = extract_due_date(text)

        if target_column == "done" && task.column_status != "done"
          {
            action_type: "complete_task",
            target_task_id: task.id,
            title: truncate_title("Tandai #{task.code} selesai: #{task.title}"),
            description: distill_core_text(text),
            target_column: "done",
            priority: priority || task.priority,
            assignee_id: assignee&.id || task.assignee_id,
            due_date: due_date || task.due_date,
            selected: true
          }
        elsif target_column.present? && target_column != task.column_status
          {
            action_type: "move_task",
            target_task_id: task.id,
            title: truncate_title("Pindahkan #{task.code} ke #{Task::COLUMNS[target_column]}: #{task.title}"),
            description: distill_core_text(text),
            target_column: target_column,
            priority: priority || task.priority,
            assignee_id: assignee&.id || task.assignee_id,
            due_date: due_date || task.due_date,
            selected: true
          }
        elsif priority.present? || assignee.present? || due_date.present?
          {
            action_type: "update_task",
            target_task_id: task.id,
            title: truncate_title("Perbarui detail #{task.code}: #{task.title}"),
            description: distill_core_text(text),
            target_column: target_column || task.column_status,
            priority: priority || task.priority,
            assignee_id: assignee&.id || task.assignee_id,
            due_date: due_date || task.due_date,
            selected: true
          }
        end
      end

      def build_new_task_action(entry)
        text = entry.raw_text
        assignee = detect_assignee(text, speaker: entry.speaker, fallback_to_speaker: true)
        priority = detect_priority(text) || "medium"
        target_column = detect_column(text) || "todo"
        due_date = extract_due_date(text)
        title = extract_clean_task_title(text)
        return nil if title.blank?

        {
          action_type: "create_task",
          title: truncate_title(title),
          description: "Diekstrak otomatis dari pembahasan rapat: #{distill_core_text(text)}",
          target_column: target_column,
          priority: priority,
          assignee_id: assignee&.id,
          due_date: due_date,
          selected: true
        }
      end

      def extract_clean_task_title(text)
        cleaned = distill_core_text(text)

        # Remove explicit task command boilerplate and polite lead-ins
        had_polite_prefix = cleaned.match?(/\A(?:tolong|mohon|minta|please)\s+/i)
        cleaned = cleaned.sub(/\A(?:tolong|mohon|minta|harus|perlu|wajib|kita\s+perlu|saya\s+(?:akan|mau)|aku\s+(?:akan|mau)|gw\s+(?:akan|mau)|please)\s+/i, "")
        cleaned = cleaned.sub(/\A(?:untuk\s+)?(?:buat(?:kan)?|bikin(?:kan)?|tambah(?:kan)?|create|add|new)\s+(?:kan\s+)?task(?:\s+baru)?(?:\s*[:\-])?\s*/i, "")

        # Remove leading "<MemberName> akan/perlu/harus/tolong" (or "<MemberName> <verb>" after "Tolong <MemberName> ...")
        member_name_tokens.each do |name|
          cleaned = cleaned.sub(/\A#{Regexp.escape(name)}\s+(?:akan|perlu|harus|bakal|tolong|silakan|diminta\s+untuk|diminta)\s+/i, "")
          cleaned = cleaned.sub(/\A#{Regexp.escape(name)}\s+(?=#{DELIVERY_VERB_PATTERN.source})/i, "") if had_polite_prefix
        end

        # Strip trailing metadata clauses cleanly
        cleaned = cleaned.gsub(/\b(?:untuk|ke|oleh|pic|assignee|assign ke)\s+(?:#{member_name_regex})\b/i, " ") if member_name_regex.present?
        cleaned = cleaned.gsub(/\bpriorit(?:y|as)\s*(?:=|:)?\s*(?:urgent|kritis|darurat|high|tinggi|medium|sedang|low|rendah|p[0-3])\b/i, " ")
        cleaned = cleaned.gsub(/\b(?:di|ke|pada|masuk)?\s*kolom\s+(?:todo|to do|in progress|progress|in review|review|done|backlog)\b/i, " ")
        cleaned = strip_deadline_phrases(cleaned)

        cleaned = cleaned.gsub(/[\s.,;:!?-]+$/, "").gsub(/\A[\s.,;:!?-]+/, "").gsub(/\s+/, " ").strip
        return "" if cleaned.blank?

        cleaned[0].upcase + cleaned[1..]
      end

      def member_name_regex
        @member_name_regex ||= begin
          tokens = member_name_tokens.sort_by { |name| -name.length }.map { |name| Regexp.escape(name) }
          tokens.join("|")
        end
      end

      def strip_deadline_phrases(text)
        result = text.dup
        result = result.gsub(/\b(?:sebelum|deadline|batas waktu|due|sampai|pada|by|on)?\s*(?:hari ini|besok|lusa|minggu ini|pekan ini|minggu depan|pekan depan|bulan depan|today|tomorrow|next week)\b/i, " ")
        result = result.gsub(/\b(?:sebelum|deadline|hari|pada|by|on)\s+(?:#{WEEKDAYS.keys.join("|")})\b/i, " ")
        result = result.gsub(/\b(?:sebelum|deadline|pada|tanggal)?\s*\d{4}-\d{2}-\d{2}\b/i, " ")
        result = result.gsub(/\b(?:sebelum|deadline|pada|tanggal)?\s*\d{1,2}\s+(?:#{INDONESIAN_MONTHS.keys.join("|")})(?:\s+\d{4})?\b/i, " ")
        result
      end

      def detect_assignee(text, speaker: nil, fallback_to_speaker: false)
        sorted_members = @team_members.sort_by { |member| -member.full_name.length }

        # Priority 1: explicit assignment preposition ("untuk Nabil", "PIC Raka", "@Nabil", "oleh Raka")
        sorted_members.each do |member|
          member_aliases(member).each do |alias_name|
            pattern = /(?:@|\b(?:untuk|ke|oleh|pic|assignee|assign(?:\s+ke)?)\s+)#{Regexp.escape(alias_name)}\b/i
            return member if text.match?(pattern)
          end
        end

        # Priority 2: "<MemberName> akan/perlu/harus/tolong/handle ..." or "tolong/minta <MemberName> ..."
        sorted_members.each do |member|
          member_aliases(member).each do |alias_name|
            pattern = /\b#{Regexp.escape(alias_name)}\s+(?:akan|perlu|harus|bakal|tolong|silakan|handle|kerjain|mengerjakan|pegang)\b/i
            polite_pattern = /\b(?:tolong|mohon|minta)\s+(?:ke\s+)?#{Regexp.escape(alias_name)}\b/i
            return member if text.match?(pattern) || text.match?(polite_pattern)
          end
        end

        return nil unless fallback_to_speaker && speaker.present?

        # Priority 3: first-person commitment ("saya/aku/gw") or direct speaker attribution
        if text.match?(/\b(?:saya|aku|gw|gue)\b/i) || !text.match?(ACTION_COMMAND_PATTERN)
          find_member_by_name(speaker)
        end
      end

      def find_member_by_name(name)
        normalized = name.to_s.downcase.strip
        return nil if normalized.blank?

        @team_members.find do |member|
          member.full_name.downcase == normalized ||
            member_aliases(member).any? { |alias_name| alias_name == normalized || normalized.split.first == alias_name }
        end
      end

      def member_aliases(member)
        parts = member.full_name.to_s.downcase.split(/\s+/).select { |part| part.length >= 2 }
        [ member.full_name.to_s.downcase, parts.first ].compact.uniq
      end

      def detect_priority(text)
        PRIORITY_PATTERNS.each do |priority, pattern|
          return priority if text.match?(pattern)
        end

        nil
      end

      def detect_column(text)
        # Prioritize explicit "kolom <column>" or "ke <column>" first
        if (match = text.match(/(?:kolom|ke)\s+(to\s*do|in\s*progress|progress|in\s*review|review|qa|done|selesai|backlog)\b/i))
          phrase = match[1].downcase
          return "todo" if phrase.match?(/to\s*do|backlog/)
          return "in_progress" if phrase.include?("progress")
          return "review" if phrase.match?(/review|qa/)
          return "done" if phrase.match?(/done|selesai/)
        end

        COLUMN_PATTERNS.each do |column, pattern|
          return column if text.match?(pattern)
        end

        nil
      end

      def extract_due_date(text, reference_date = Date.current)
        if (iso_match = text.match(/\b(\d{4}-\d{2}-\d{2})\b/))
          return Date.iso8601(iso_match[1])
        end

        if (dmy_match = text.match(/\b(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})\b/))
          year = dmy_match[3].length == 2 ? 2000 + dmy_match[3].to_i : dmy_match[3].to_i
          return Date.new(year, dmy_match[2].to_i, dmy_match[1].to_i)
        end

        if (named_date = text.match(/\b(\d{1,2})\s+(#{INDONESIAN_MONTHS.keys.join("|")})(?:\s+(\d{4}))?\b/i))
          day = named_date[1].to_i
          month = INDONESIAN_MONTHS[named_date[2].downcase]
          year = named_date[3] ? named_date[3].to_i : reference_date.year
          candidate = Date.new(year, month, day)
          candidate = candidate.next_year if named_date[3].nil? && candidate < reference_date - 30.days
          return candidate
        end

        return reference_date if text.match?(/\b(?:hari ini|today|sekarang)\b/i)
        return reference_date + 1.day if text.match?(/\b(?:besok|tomorrow)\b/i)
        return reference_date + 2.days if text.match?(/\blusa\b/i)
        return reference_date.end_of_week(:sunday) if text.match?(/\b(?:minggu ini|pekan ini|this week)\b/i)
        return reference_date + 7.days if text.match?(/\b(?:minggu depan|pekan depan|next week)\b/i)
        return reference_date.next_month if text.match?(/\b(?:bulan depan|next month)\b/i)

        if (wday_match = text.match(/\b(?:sebelum|deadline|hari|pada|sampai|by|on|next)\s+(#{WEEKDAYS.keys.join("|")})\b/i))
          target_wday = WEEKDAYS[wday_match[1].downcase]
          return next_weekday(reference_date, target_wday)
        end

        nil
      rescue Date::Error
        nil
      end

      def next_weekday(reference_date, target_wday)
        delta = (target_wday - reference_date.wday) % 7
        delta = 7 if delta.zero?
        reference_date + delta.days
      end

      def truncate_title(title)
        cleaned = title.to_s.gsub(/\s+/, " ").strip
        return "" if cleaned.blank?

        cleaned.length > 140 ? "#{cleaned[0, 137].rstrip}..." : cleaned
      end

      def build_fathom_summary(entries, actions)
        scored = score_entries(entries)
        decisions = select_by_tag(scored, :decision, limit: 4)
        blockers = select_by_tag(scored, :blocker, limit: 4)
        key_points = select_key_points(scored, decisions: decisions, blockers: blockers, limit: 5)
        tldr = synthesize_tldr(key_points: key_points, decisions: decisions, blockers: blockers, actions: actions)

        sections = [ "Ringkasan Rapat: #{@meeting.title} (#{@meeting.room_code})" ]
        sections << "[TL;DR]\n#{tldr}"
        sections << format_bullet_section("POIN KUNCI", key_points.map { |entry| format_entry_bullet(entry) }) if key_points.any?
        sections << format_bullet_section("KEPUTUSAN", decisions.map { |entry| format_entry_bullet(entry, include_speaker: false) }) if decisions.any?
        sections << format_bullet_section("BLOCKER", blockers.map { |entry| format_entry_bullet(entry) }) if blockers.any?
        sections << format_action_summary_section(actions)
        sections.join("\n\n")
      end

      def score_entries(entries)
        return [] if entries.empty?

        frequencies = Hash.new(0)
        entries.each do |entry|
          meaningful_tokens(entry.text).each { |token| frequencies[token] += 1 }
        end

        entries.map.with_index do |entry, idx|
          tokens = meaningful_tokens(entry.text)
          tfidf_score = tokens.sum { |token| frequencies[token] } / [ tokens.size.to_f, 1.0 ].max

          tag_bonus = case entry.tag
          when :decision then 5.0
          when :blocker then 4.5
          when :action then 3.5
          when :note then 2.5
          else 0.0
          end

          signal_bonus = 0.0
          signal_bonus += 1.5 if find_task_match(entry.raw_text).present?
          signal_bonus += 1.0 if entry.text.match?(/\b(?:karena|penyebab|solusi|target|rilis|deadline|dampak|api|database|staging|produksi|production)\b/i)
          signal_bonus -= 1.0 if tokens.size < 3

          {
            entry: entry,
            order: idx,
            score: tfidf_score + tag_bonus + signal_bonus
          }
        end
      end

      def select_by_tag(scored, tag, limit:)
        scored
          .select { |item| item[:entry].tag == tag }
          .sort_by { |item| [ -item[:score], item[:order] ] }
          .first(limit)
          .sort_by { |item| item[:order] }
          .map { |item| item[:entry] }
      end

      def select_key_points(scored, decisions:, blockers:, limit:)
        excluded = (decisions + blockers).map(&:object_id).to_set

        discussion_points = scored
          .reject { |item| excluded.include?(item[:entry].object_id) || item[:entry].tag == :action }
          .sort_by { |item| [ -item[:score], item[:order] ] }
          .first(limit)
          .sort_by { |item| item[:order] }
          .map { |item| item[:entry] }

        return discussion_points if discussion_points.any?

        non_decision_or_blocker = scored
          .reject { |item| excluded.include?(item[:entry].object_id) }
          .sort_by { |item| [ -item[:score], item[:order] ] }
          .first(limit)
          .sort_by { |item| item[:order] }
          .map { |item| item[:entry] }

        return non_decision_or_blocker if non_decision_or_blocker.any?

        scored.sort_by { |item| [ -item[:score], item[:order] ] }.first([ limit, 3 ].min).map { |item| item[:entry] }
      end

      def synthesize_tldr(key_points:, decisions:, blockers:, actions:)
        parts = []

        if key_points.any?
          parts << ensure_period(key_points.first.text)
        elsif decisions.any?
          parts << ensure_period(decisions.first.text)
        elsif blockers.any?
          parts << ensure_period(blockers.first.text)
        elsif actions.any?
          parts << "Rapat menyelaraskan #{actions.size} tindak lanjut prioritas untuk board #{@project.key}."
        else
          return "Belum ada catatan percakapan atau keputusan substansial yang cukup untuk dirangkum."
        end

        if decisions.any?
          decision_summary = decisions.first(2).map { |entry| trim_clause(entry.text, max: 95) }.join("; ")
          parts << "Keputusan utama: #{ensure_period(decision_summary)}" unless parts.first.downcase.include?(decision_summary.downcase)
        end

        outcomes = []
        outcomes << "#{blockers.size} blocker/risiko teridentifikasi" if blockers.any?
        if actions.any?
          pics = actions.filter_map { |item| @team_members.find { |user| user.id == item[:assignee_id] }&.full_name&.split&.first }.uniq
          pic_suffix = pics.any? ? " (PIC: #{pics.join(', ')})" : ""
          outcomes << "#{actions.size} usulan Kanban disiapkan#{pic_suffix}"
        end
        parts << "#{outcomes.join(' dan ')}." if outcomes.any?

        parts.join(" ")
      end

      def format_bullet_section(header, bullets)
        "[#{header}]\n" + bullets.map { |bullet| "- #{bullet}" }.join("\n")
      end

      def format_entry_bullet(entry, include_speaker: true)
        body = ensure_period(entry.text)
        return body unless include_speaker && entry.speaker.present?

        "#{entry.speaker.split.first}: #{body}"
      end

      def format_action_summary_section(actions)
        if actions.empty?
          return "[TINDAK LANJUT]\n- Tidak ada usulan perubahan Kanban otomatis; tambahkan manual jika diperlukan."
        end

        lines = actions.map do |item|
          assignee = @team_members.find { |user| user.id == item[:assignee_id] }
          meta = []
          meta << Task::COLUMNS.fetch(item[:target_column], item[:target_column]) if item[:target_column].present?
          meta << "Prioritas #{item[:priority]}" if item[:priority].present?
          meta << "PIC: #{assignee.full_name}" if assignee
          meta << "Deadline: #{item[:due_date].strftime('%d %b %Y')}" if item[:due_date].present?
          "- #{item[:title]} (#{meta.join(' · ')})"
        end

        "[TINDAK LANJUT]\n#{lines.join("\n")}"
      end

      def trim_clause(text, max:)
        cleaned = text.to_s.strip.sub(/[.;,]+\z/, "")
        cleaned.length > max ? "#{cleaned[0, max - 3].rstrip}..." : cleaned
      end

      def ensure_period(text)
        cleaned = text.to_s.strip
        return "" if cleaned.blank?

        capitalized = cleaned[0].upcase + cleaned[1..]
        capitalized.match?(/[.!?]\z/) ? capitalized : "#{capitalized}."
      end
  end
end
