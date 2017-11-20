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
  option :filter,
         short: '-f FILTER',
         long: '--filter FILTER',
         description: 'String representation of the filter to apply',
         default: '{}'

  def gather_events(events)
    useful_events = events.reject { |x| (x[:code] =~ /system-reboot|instance-stop|system-maintenance/) || (x[:description] =~ /\[Completed\]|\[Canceled\]/) }
    !useful_events.empty?
  end

  def gather_status(status_checks)
    ['impaired', 'insufficient-data'].include? status_checks.status
  end

  def run
    filter = Filter.parse(config[:filter])
    options = if filter.empty?
                {}
              else
                { filters: filter }
              end

    messages = []

    ec2 = Aws::EC2::Client.new
    instance_ids = []

    instances = ec2.describe_instances(options)
    instances.reservations.each do |r|
      r.instances.each do |i|
        instance_ids.push(i[:instance_id])
      end
    end

    begin
      resp = []
      instance_ids.each_slice(100) do |batch|
        resp << ec2.describe_instance_status(instance_ids: batch)
      end
      resp.each do |r|
        r.instance_statuses.each do |item|
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
      end
    rescue StandardError => e
      unknown "An error occurred processing AWS EC2 API: #{e.message}"
    end

    if messages.count > 0
      critical("#{messages.count} instances #{messages.count > 1 ? 'have' : 'has'}: #{messages.join(',')}")
    else
      ok
    end
  end
end
