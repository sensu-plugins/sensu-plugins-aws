#!/usr/bin/env ruby
#
# This handler assumes it runs on an ec2 instance with an iam role
# that has permission to send to the sns topic specified in the config.
# This removes the requirement to specify an access key and secret access key.
# See http://docs.aws.amazon.com/IAM/latest/UserGuide/WorkingWithRoles.html
#
# Requires the aws-sdk gem.
#
# Setting required in sns.json
#   topic_are  :  The arn for the destination sns topic
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details

require 'sensu-handler'
require 'aws-sdk-v1'
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

  def use_ami_role
    use_ami_role = settings['sns']['use_ami_role']
    use_ami_role.nil? ? true : use_ami_role
  end

  def aws_access_key
    settings['sns']['access_key'] || ''
  end

  def aws_access_secret
    settings['sns']['secret_key'] || ''
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
    if use_ami_role
      AWS.config(region: region)
    else
      AWS.config(access_key_id: aws_access_key,
                 secret_access_key: aws_access_secret,
                 region: region)
    end

    sns = AWS::SNS.new

    t = sns.topics[topic_arn]

    subject = if @event['action'].eql?('resolve')
                "RESOLVED - [#{event_name}]"
              else
                "ALERT - [#{event_name}]"
              end
    options = { subject: subject }
    t.publish("#{subject} - #{message}", options)
  rescue => e
    puts "Exception occured in SnsNotifier: #{e.message}", e.backtrace
  end
end
