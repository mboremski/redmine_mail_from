require_dependency 'mailer'

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
        from_domain = mail_from_domain(from)
        to_domains = self.class.email_addresses(headers[:to]).map do |address|
          mail_from_domain(address)
        end

        if from_domain.blank? || to_domains.empty? ||
           to_domains.any? { |domain| domain != from_domain }
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
