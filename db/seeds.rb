# Production & initial workspace bootstrap script (tanpa akun/data dummy).
# Cara membuat akun Team Lead awal lewat CLI:
#   SYNCBOARD_LEAD_EMAIL=admin@perusahaan.com SYNCBOARD_LEAD_PASSWORD=password_kuat ruby bin/rails db:seed
# Atau langsung daftar pengguna pertama lewat halaman /registration/new (otomatis menjadi Team Lead).

lead_email = ENV["SYNCBOARD_LEAD_EMAIL"].to_s.strip.downcase
lead_password = ENV["SYNCBOARD_LEAD_PASSWORD"].to_s

if lead_email.present? && lead_password.present?
  user = User.find_or_initialize_by(email_address: lead_email)
  user.assign_attributes(
    full_name: ENV.fetch("SYNCBOARD_LEAD_NAME", "Team Lead"),
    department: ENV.fetch("SYNCBOARD_LEAD_DEPARTMENT", "Engineering"),
    job_title: ENV.fetch("SYNCBOARD_LEAD_TITLE", "Team Lead"),
    role: "lead",
    active: true,
    password: lead_password,
    password_confirmation: lead_password
  )
  user.save!
  puts "Akun Team Lead siap digunakan: #{user.email_address} (#{user.employee_code})"
else
  puts "Seed dilewati: tidak ada data demo dibuat."
  puts "Buka /registration/new untuk mendaftarkan pengguna pertama sebagai Team Lead, atau set SYNCBOARD_LEAD_EMAIL & SYNCBOARD_LEAD_PASSWORD."
end
