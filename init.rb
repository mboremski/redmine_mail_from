Redmine::Plugin.register :redmine_mail_from do
  name 'Redmine Mail From plugin'
  author 'Takeshi Nakamura, Alexey Smirnov'
  description 'Extends mail "From:" header field'
  version '3.2.0'
  url 'https://github.com/apsmir/redmine_mail_from'
  author_url 'https://github.com/apsmir'
  requires_redmine :version_or_higher => '6.1'

  # Domains whose recipients may see the issue subject.
  # Empty falls back to the domain of the emission address.
  settings :default => { 'internal_domains' => '' },
           :partial => 'settings/redmine_mail_from'
end

# Redmine::PluginLoader adds plugins/*/lib to Rails.autoloaders.main with
# eager_load: true and runs init.rb inside Rails.application.config.to_prepare.
# So no require for files below lib -- referencing the constant is enough, and
# RedmineMailFrom::Hooks registers its view listener on eager load. A nested
# to_prepare would be redundant and would add another block on every reload;
# after_initialize ran only once at boot and lost the patch when Mailer was
# reloaded.
unless Mailer < RedmineMailFrom::MailerModelPatch
  Mailer.prepend RedmineMailFrom::MailerModelPatch
end
