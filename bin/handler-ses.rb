#!/usr/bin/env ruby
#
#
# This handler formats alerts as mails and sends them off to a pre-defined recipient.
#
# Requires the aws-sdk gem.
#
# Setting required in ses.json
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'sensu-handler'
require 'aws-sdk'

class SESNotifier < Sensu::Handler
  def event_name
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def action_to_string
    @event['action'].eql?('resolve') ? 'RESOLVED' : 'ALERT'
  end

  def status_to_string
    case @event['check']['status']
    when 0
      'OK'
    when 1
      'WARNING'
    when 2
      'CRITICAL'
    else
      'UNKNOWN'
    end
  end

  def mail_from
    settings['ses']['mail_from'] || ''
  end

  def build_mail_to_list
    json_config = config[:json_config] || 'ses'
    mail_to = @event['check']['mail_to'] || @event['client']['mail_to'] || settings[json_config]['mail_to']
    if settings[json_config].key?('subscriptions')
      @event['check']['subscribers'].each do |sub|
        if settings[json_config]['subscriptions'].key?(sub)
          mail_to << ", #{settings[json_config]['subscriptions'][sub]['mail_to']}"
        end
      end
    end
    mail_to
  end

  def region
    settings['ses']['region'] || 'us-east-1'
  end

  def handle
    mail_to = build_mail_to_list
    body = <<-BODY.gsub(/^\s+/, '')
            #{@event['check']['output']}
            Host: #{@event['client']['name']}
            Timestamp: #{Time.at(@event['check']['issued'])}
            Address:  #{@event['client']['address']}
            Check Name:  #{@event['check']['name']}
            Command:  #{@event['check']['command']}
            Status:  #{@event['check']['status']}
            Occurrences:  #{@event['occurrences']}
          BODY

    subject = if @event['check']['notification'].nil?
                "#{action_to_string} - #{event_name}: #{status_to_string}"
              else
                "#{action_to_string} - #{event_name}: #{@event['check']['notification']}"
              end

    message = {
      subject: {
        data: subject
      },
      body: {
        text: {
          data: body
        }
      }
    }

    ses = Aws::SES::Client.new(region: region)

    begin
      Timeout.timeout(10) do
        ses.send_email(
          source: mail_from,
          destination: {
            to_addresses: mail_to.split(',')
          },
          message: message
        )

        puts 'mail -- sent alert for ' + event_name + ' to ' + mail_to.to_s
      end
    rescue Timeout::Error
      puts 'mail -- timed out while attempting to ' + @event['action'] + ' an incident -- ' + event_name
    end
  end
end
