module RedmineMailFrom
  module MailerModelPatch

    def mail(headers={}, &block)

      placeholder = {
        '%f' => @author ? @author.firstname : nil,
        '%l' => @author ? @author.lastname : nil,
        '%m' => (@author && @author.mail && !@author.pref.hide_mail) ?
        @author.mail : nil,
        '%u' => @author ? @author.login : nil,
        '%p' => @issue ? @issue.project.name : nil
      }

      from = ''

      Setting.mail_from.split(/\s*::\s*/).each do |s|
        nerr = 0

        placeholder.each do |key, val|
          next unless s.match(/#{key}/)

          if val.nil? then nerr += 1 end

          s.gsub!(/#{key}/, val || '')
        end

        from = s

        break if nerr == 0
      end

      host = Setting.host_name.split(/[\/:]/).first

      if @issue
        listid = "<#{@issue.project.identifier}.#{host}>"

        # headers[:to] may be a User, an array of Users and/or strings, nil or
        # empty. Mailer.email_addresses resolves all of them to addresses.
        internal_domains = mail_from_internal_domains(from)
        to_domains = self.class.email_addresses(headers[:to]).map do |address|
          mail_from_domain(address)
        end

        if to_domains.empty? ||
           to_domains.any? { |domain| domain.blank? || internal_domains.exclude?(domain) }
          headers[:subject] =
            "[#{@issue.project.name} - #{@issue.tracker.name} ##{@issue.id}] "
        end
      else
        listid = "<#{host}>"
      end

      # An empty From header is invalid and cannot be corrected by Redmine's
      # own reverse_merge! once the key exists.
      headers['From'] = from if from.present?
      headers['List-Id'] = listid

      super(headers, &block)
    end

    private

    # Domains whose recipients may see the issue subject: the configured list
    # plus the domain of the emission address, which is internal by
    # definition. An empty setting therefore behaves exactly like the previous
    # comparison against the From header instead of silently shortening every
    # subject. Compared for equality -- subdomains need their own entry.
    def mail_from_internal_domains(from_header = nil)
      configured =
        Setting.plugin_redmine_mail_from['internal_domains'].to_s
               .downcase.split(/[\s,;]+/)
               .map { |domain| domain.strip.sub(/\A@/, '') }

      (configured << mail_from_domain(from_header)).reject(&:blank?).uniq
    end

    # Domain of a mail address, downcased, or nil.
    #
    # address.split('@').last returns the domain with a trailing '>' whenever
    # the address carries a display name -- which is what the placeholder form
    # "%f %l <%m>" produces.
    def mail_from_domain(address)
      return nil if address.blank?

      Mail::Address.new(address.to_s).domain.presence&.downcase
    rescue StandardError
      address.to_s[/@([^@>\s]+)/, 1]&.downcase
    end
  end
end
