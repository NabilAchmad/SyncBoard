# Panduan Belajar Ruby & Ruby on Rails 8 — Studi Kasus: **SyncBoard (Team Workspace, Kanban & Video Meeting Room)**

Panduan ini disusun khusus untuk Anda yang **sudah paham pemrograman** (Java, Kotlin, TypeScript/JavaScript, PHP, SQL, Python), dan ingin memahami bagaimana **Ruby on Rails 8** menangani aplikasi kolaborasi real-time berskala besar.

Project di folder ini adalah **SyncBoard**, aplikasi **Team Workspace & Kanban Board Real-Time** yang dilengkapi **Video Call Meeting Room (WebRTC)**, **Live Speech-to-Text / Notulensi**, serta alur **Generate Rangkuman → ACC Team Lead → Auto-Update Kanban Board**.

---

## 1. Kenapa Rails 8 Bagus untuk Project Kompleks?

| Konsep | Stack Tradisional (React + Node/Spring) | Ruby on Rails 8 (SyncBoard) |
| :--- | :--- | :--- |
| **Real-Time Broadcast** | Perlu setup Socket.IO / Redis pub-sub + Redux state sync di frontend | **Turbo Streams Broadcasts (`broadcast_replace_to`)** — server me-render partial HTML & mendorong update via WebSocket langsung ke semua browser |
| **WebRTC Signaling** | Terpisah di microservice Node.js/WS | **ActionCable (`MeetingChannel`)** terintegrasi langsung dengan autentikasi cookie `ApplicationCable::Connection` |
| **Bisnis Logic Rumit** | Menumpuk di Controller / Service layer | **Service Objects (`app/services/`)** memisahkan transaksi kompleks dari Controller agar mudah diuji |
| **Atomic Data Integrity** | Manual `try/catch` + rollback SQL | **`ActiveRecord::Base.transaction`** menjamin ACC rapat menerapkan seluruh perubahan Kanban atau rollback 100% jika ada error |

---

## 2. Arsitektur **SyncBoard** (`app/`)

### A. Models (`app/models/`) — Domain & Relasi
1. **[User](file:///d:/Semester%207/GG/GIGI/app/models/user.rb)**: Autentikasi `bcrypt` (`has_secure_password`), role `member` (Anggota Tim) dan `lead` (Team Lead yang memegang hak ACC rapat), kode tim otomatis (`TM-001`), serta upload avatar via ActiveStorage.
2. **[Project](file:///d:/Semester%207/GG/GIGI/app/models/project.rb)**: Menyimpan kode board (`SYNC`, `MOB`), task-task, meeting rooms, serta method `broadcast_kanban_refresh!` untuk menyegarkan papan Kanban & Activity Feed di semua browser secara live.
3. **[Task](file:///d:/Semester%207/GG/GIGI/app/models/task.rb)**: Kartu Kanban pada 4 kolom (`todo`, `in_progress`, `review`, `done`), prioritas (`low`..`urgent`), auto-code (`SYNC-1`, `SYNC-2`), urutan `position`, dan relasi `source_meeting` jika dibuat dari hasil rapat.
4. **[Meeting](file:///d:/Semester%207/GG/GIGI/app/models/meeting.rb)**: Ruang diskusi dengan `room_code` unik (`SYNC-LIVE`), status (`live` → `summary_ready` → `approved` / `rejected`), `transcript_text`, `summary_text`, serta `broadcast_summary_refresh!`.
5. **[MeetingMessage](file:///d:/Semester%207/GG/GIGI/app/models/meeting_message.rb)**: Pesan chat, catatan (`note`), atau keputusan (`decision`) di dalam meeting room yang otomatis di-broadcast lewat callback `after_create_commit`.
6. **[MeetingActionItem](file:///d:/Semester%207/GG/GIGI/app/models/meeting_action_item.rb)**: Daftar usulan perubahan Kanban (`create_task`, `move_task`, `update_task`, `complete_task`) hasil rangkuman rapat sebelum di-ACC Lead.

### B. Service Objects (`app/services/`) — Pola Arsitektur Skala Besar
Daripada menaruh ratusan baris logika di Controller ("Fat Controller"), SyncBoard memecah proses bisnis ke Service Object:
- **[Tasks::Move](file:///d:/Semester%207/GG/GIGI/app/services/tasks/move.rb)**: Memindahkan kartu antar kolom Kanban secara atomik, mengurutkan ulang `position`, mencatat [ActivityLog](file:///d:/Semester%207/GG/GIGI/app/models/activity_log.rb), dan mem-broadcast perubahan board ke seluruh klien.
- **[Meetings::SummaryGenerator](file:///d:/Semester%207/GG/GIGI/app/services/meetings/summary_generator.rb)**: Menganalisis `transcript_text` + pesan rapat bertipe `decision`/`note` menjadi ringkasan & daftar `MeetingActionItem` (mendeteksi kode task seperti `SYNC-1`, target kolom, prioritas, dan nama PIC; opsional memakai `ENV["GEMINI_API_KEY"]` jika diset).
- **[Meetings::ApplySummary](file:///d:/Semester%207/GG/GIGI/app/services/meetings/apply_summary.rb)**: Dijalankan saat Team Lead menekan **ACC & Terapkan ke Kanban**. Mengeksekusi seluruh item terpilih dalam satu `ActiveRecord::Base.transaction`, membuat/memindah/menyelesaikan task di Kanban, dan langsung mem-broadcast pembaruan ke board & meeting room.

### C. Real-Time WebSocket & Frontend (`app/channels/` & `app/javascript/controllers/`)
- **[MeetingChannel](file:///d:/Semester%207/GG/GIGI/app/channels/meeting_channel.rb)**: Mengautentikasi koneksi WebSocket via cookie sesi dan merelay sinyal WebRTC (`join`, `signal` berupa `offer`/`answer`/`ice_candidate`, `media_state`, `transcript_chunk`, `peer_left`).
- **[meeting_room_controller.js](file:///d:/Semester%207/GG/GIGI/app/javascript/controllers/meeting_room_controller.js)**: Stimulus controller untuk WebRTC mesh peer-to-peer video/audio, fallback otomatis ke mode observer jika kamera sedang dipakai tab lain, screen share (`getDisplayMedia`), Web Speech API (`id-ID`) live captions, serta auto-save transcript.
- **[kanban_controller.js](file:///d:/Semester%207/GG/GIGI/app/javascript/controllers/kanban_controller.js)**: Stimulus controller untuk drag-and-drop kartu Kanban yang mengirim `PATCH /projects/:project_id/tasks/:id/move`.

---

## 3. Persiapan & Menjalankan di Live (Production + Neon PostgreSQL)

1. Pastikan domain publik menggunakan **HTTPS** agar fitur **WebRTC (Kamera & Mikrofon)** serta **Live Speech-to-Text** diizinkan browser.
2. Salin [.env.example](file:///d:/Semester%207/GG/GIGI/.env.example) menjadi `.env` (jangan pernah commit `.env` ke git) atau set langsung di dashboard hosting Anda (Render, Railway, Kamal, Fly, atau VPS):
   - `DATABASE_URL` = connection string **Neon PostgreSQL** (`?sslmode=require`). Semua tabel aplikasi termasuk Solid Cache, Solid Queue, dan Solid Cable berjalan di satu database utama sehingga langsung kompatibel dengan satu Neon DB (mendukung pooled `-pooler` maupun direct connection).
   - `RAILS_MASTER_KEY` (dari `config/master.key`).
   - `APP_HOST=domain-anda.com` dan `APP_PROTOCOL=https`
   - `ASSUME_SSL=true` & `FORCE_SSL=true` (aktif di balik reverse proxy / TLS; otomatis terhubung dengan ActionCable WebSocket `wss://`).
   - `GEMINI_API_KEY` (opsional, untuk AI summary Google Gemini selain parser lokal bawaan).
   - `TURN_URL`, `TURN_USERNAME`, `TURN_CREDENTIAL` atau `WEBRTC_ICE_SERVERS_JSON` (opsional, direkomendasikan bila peserta berada di jaringan seluler/kantor dengan NAT ketat).
3. Jalankan migrasi & siapkan database Neon:
   ```bash
   ./bin/rails db:prepare
   ```
4. **Bootstrap Team Lead pertama (tanpa data demo):**
   - Cara termudah: buka `/registration/new` di aplikasi Live Anda; pengguna pertama yang mendaftar pada database kosong otomatis menjadi **Team Lead**.
   - Atau lewat CLI:
     ```bash
     SYNCBOARD_LEAD_EMAIL=lead@perusahaan.com SYNCBOARD_LEAD_PASSWORD=password_kuat ./bin/rails db:seed
     ```
5. Team Lead kemudian dapat mengangkat anggota lain menjadi Team Lead atau menonaktifkan akun lewat menu **Kelola Anggota Tim** (`/team_members`).

---

## 4. Perintah Berguna Selama Belajar Rails

```powershell
# Jalankan seluruh automated tests (Models, Services, Channels, Integration)
ruby bin/rails test

# Isi ulang data contoh SyncBoard
ruby bin/rails db:seed

# Build CSS Tailwind v4 secara manual
ruby bin/rails tailwindcss:build

# Cek seluruh URL route yang tersedia
ruby bin/rails routes
```
