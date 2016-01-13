#! /usr/bin/env ruby
#
# check-instance-health
#
# DESCRIPTION:
#   This plugin looks up all instances in an account and checks event data, system status
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: aws-sdk
#   gem: sensu-plugin
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Shane Starcher
#   Copyright (c) 2016
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugins-aws'
require 'sensu-plugin/check/cli'
require 'aws-sdk'

class CheckInstanceEvents < Sensu::Plugin::Check::CLI
  include Common

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default: 'us-east-1'

  def gather_events(events)
    useful_events = events.reject { |x| x[:code] == 'system-reboot' && x[:description] =~ /\[Completed\]/ }
    !useful_events.empty?
  end

  def gather_status(status_checks)
    ['impaired', 'insufficient-data'].include? status_checks.status
  end

  def run
    messages = []
    ec2 = Aws::EC2::Client.new
    begin
      ec2.describe_instance_status.instance_statuses.each do |item|
        id = item.instance_id
        if gather_events(item.events)
          messages << "#{id} has unscheduled events"
        end

        if gather_status(item.system_status)
          messages << "#{id} has failed system status checks"
        end

        if gather_status(item.instance_status)
          messages << "#{id} has failed instance status checks"
        end
      end
    rescue => e
      unknown "An error occurred processing AWS EC2 API: #{e.message}"
    end

    if messages.count > 0
      critical("#{messages.count} instances #{messages.count > 1 ? 'have' : 'has'}: #{messages.join(',')}")
    else
      ok
    end
  end
end
