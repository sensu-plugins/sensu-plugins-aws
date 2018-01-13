#!/usr/bin/env ruby
#
# Send notifications to an SNS topic
#
# Requires the aws-sdk gem.
#
# See README for usage information
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details

require 'sensu-handler'
require 'aws-sdk'
require 'erubis'

class SnsNotifier < Sensu::Handler
  def topic_arn
    settings['sns']['topic_arn']
  end

  def region
    settings['sns']['region'] || 'us-east-1'
  end

  def event_name
    "#{@event['client']['name']}/#{@event['check']['name']}"
  end

  def message
    template = if template_file && File.readable?(template_file)
                 File.read(template_file)
               else
                 <<-BODY.gsub(/^\s+/, '')
        <%= @event['check']['notification'] || @event['check']['output'] %>
      BODY
               end
    eruby = Erubis::Eruby.new(template)
    eruby.result(binding)
  end

  def template_file
    settings['sns']['template_file']
  end

  def handle
    sns = Aws::SNS::Client.new(region: region)

    subject = if @event['action'].eql?('resolve')
                "RESOLVED - [#{event_name}]"
              else
                "ALERT - [#{event_name}]"
              end

    options = {
      subject: subject,
      message: "#{subject} - #{message}",
      topic_arn: topic_arn
    }

    sns.publish(options)
  rescue StandardError => e
    puts "Exception occured in SnsNotifier: #{e.message}", e.backtrace
  end
end
