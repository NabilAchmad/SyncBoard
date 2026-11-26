<div align="center">
  <img src="public/icon.svg" alt="SyncBoard Logo" width="56" height="56" />
  <h1>SyncBoard</h1>
  <p>
    <strong>Ruang rapat tim &amp; Kanban Board real-time dalam satu alur kerja:</strong><br />
    diskusikan di video room, ekstrak inti pembahasan bergaya Fathom secara lokal, lalu terapkan ke board setelah ACC Team Lead.
  </p>
  <p>
    <a href="https://sync-board-zeta.vercel.app">Live Demo</a> ·
    <span>Ruby 3.4.13</span> ·
    <span>Rails 8.1</span> ·
    <span>Hotwire &amp; Tailwind CSS v4</span> ·
    <span>WebRTC + ActionCable</span>
  </p>
</div>

---

## Inti Masalah & Solusi

Dalam tim engineering, keputusan dan pembagian tugas saat rapat sering tercecer di catatan chat atau lupa dipindahkan ke board. **SyncBoard** menyatukan **Kanban Board** dan **Meeting Room** dalam satu aplikasi:

```text
Video Room + Live Chat / Quick Highlight (Poin · Keputusan · Aksi · Blocker)
        │
        ▼
Fathom-style Local Extractor (TL;DR, Keputusan, Blocker, Poin Kunci, Usulan Tiket)
        │
        ▼
Review & ACC Team Lead (dengan locking anti duplikasi) ──▶ Kanban Board Otomatis Update
```

---

## Fitur Utama

* **Workspace Tim & Kanban Real-time:** Dukungan multi-tim berbasis kode undangan 6 karakter (`Team Lead` & `Member`), papan 4 kolom (`To Do`, `In Progress`, `In Review`, `Done`), prioritas, tenggat waktu (*approaching / overdue badge*), tombol penyelesaian proyek, serta pembaruan board otomatis via **Turbo Streams**.
* **Meeting Room (WebRTC + ActionCable):** Video/audio call peer-to-peer, *screen sharing*, mirror kamera, **Live Captions** (*Web Speech API*), **Chat Live**, serta **Quick Highlight Tags** (`Poin`, `Keputusan`, `Aksi`, `Blocker`) yang tersinkronisasi ke seluruh peserta.
* **Ekstraktor Inti Bergaya Fathom (100% Lokal):** Berjalan langsung di server tanpa API key LLM eksternal (`Meetings::SummaryGenerator`). Menyaring basa-basi & duplikasi *speech-to-text*, lalu menyusun kartu **TL;DR Inti Rapat**, **Keputusan Disepakati**, **Blocker & Risiko**, **Poin Pembahasan Utama**, serta usulan aksi Kanban (deteksi PIC, kolom target, prioritas, dan deadline alami seperti `hari ini`, `besok`, `lusa`, `minggu depan`, atau tanggal).
* **Persetujuan (*Human-in-the-Loop*) & Keamanan:** Usulan tiket baru maupun pembaruan status tiket lama dapat ditinjau/diubah sebelum di-ACC oleh Team Lead (`with_lock` idempoten agar klik ganda tidak menggandakan tiket), disertai proteksi akses berbasis tim/peran dan *rate limiting* pada login, registrasi, reset password, serta kode undangan.
* **Tema Terra Light & Dark Terra:** Antarmuka responsif dengan pilihan mode Terang, Gelap, atau Sistem.

---

## Tech Stack

| Lapisan | Teknologi |
| :--- | :--- |
| **Backend** | Ruby `3.4.13`, Ruby on Rails `8.1`, Puma, Propshaft |
| **Frontend** | Hotwire (Turbo & Stimulus), Importmap ESM, Tailwind CSS `v4` |
| **Real-time & Media** | WebRTC P2P (`STUN`/`TURN`), ActionCable (`solid_cable`) |
| **Database & Infra** | PostgreSQL (Neon `-pooler` di production), SQLite3 (dev/test fallback), `solid_cache`, `solid_queue` |
| **Quality & Security** | Minitest, RuboCop Rails Omakase, Brakeman, Bundler-Audit, Importmap Audit, GitHub Actions CI |

---

## Menjalankan Secara Lokal

### Prasyarat
* Ruby `3.4.x` dan Bundler
* Node.js (untuk pemeriksaan/tooling opsional) & `libvips` (untuk Active Storage avatar di Linux)

### Langkah Setup
```bash
# 1. Install dependensi gem
bundle install

# 2. (Opsional) Salin template environment bila ingin memakai PostgreSQL/Neon atau TURN server
cp .env.example .env

# 3. Siapkan database lokal (default SQLite di storage/ jika DATABASE_URL kosong)
bin/rails db:prepare

# 4. Jalankan server Rails + Tailwind CSS watcher
bin/dev          # macOS / Linux
# atau di Windows:
dev.bat
```

Buka **`http://localhost:3000`**. Pada database kosong, akun pertama yang mendaftar lewat `/registration/new` otomatis menjadi **Team Lead** dan dapat langsung membuat tim.

---

## Pengujian & Pemeriksaan Kualitas

```bash
# Jalankan seluruh test suite
bin/rails test

# Lint gaya kode Ruby/Rails
bin/rubocop

# Static security scan & audit dependensi
bin/brakeman --no-pager --summary
bin/bundler-audit
bin/importmap audit
```

---

## Konfigurasi Production & Deployment

Aplikasi dilengkapi [Dockerfile](Dockerfile), [deploy.yml](config/deploy.yml) (Kamal), serta konfigurasi region `sin1` pada [vercel.json](vercel.json). Variabel penting untuk environment production (lihat [`.env.example`](.env.example)):

* `DATABASE_URL` — string koneksi PostgreSQL / Neon (sertakan `?sslmode=require`; suffix `-pooler.` otomatis menonaktifkan *prepared statements* & *advisory locks* untuk PgBouncer).
* `RAILS_MASTER_KEY` — kunci dekripsi `config/credentials.yml.enc`.
* `APP_HOST`, `APP_PROTOCOL`, `ASSUME_SSL`, `FORCE_SSL` — konfigurasi host & HTTPS.
* `SOLID_QUEUE_IN_PUMA=false` — disarankan pada runtime *serverless* agar tidak mem-fork worker di proses web.
* `TURN_URL`, `TURN_USERNAME`, `TURN_CREDENTIAL` *(opsional)* — direkomendasikan agar WebRTC tetap tembus di jaringan seluler atau kantor dengan NAT ketat.
* **Healthcheck:** `/up` (liveness rack cepat) dan `/up/warm` (ping ringan `SELECT 1` untuk menjaga instance & koneksi DB tetap siap).
