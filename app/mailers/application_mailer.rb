class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "SyncBoard <noreply@syncboard.local>")
  layout "mailer"
end
