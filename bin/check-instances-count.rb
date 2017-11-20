#! /usr/bin/env ruby
#
# check-instances-count
#
#
# DESCRIPTION:
#   This plugin checks the instances count for a specific auto scale group ( ASG ).
#   Goal is to allow you to monitor that your ASG isnt out of control
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
#     check-instances-count.rb --warn 15 --crit 25 --groupname logstash-instances-auto
#
#
#
# NOTES:
#
# LICENSE:
#   Copyright (c) 2015, Kevin Bond
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugins-aws'
require 'sensu-plugin/check/cli'
require 'aws-sdk'

# Class to check the instance count
class CheckInstanceCount < Sensu::Plugin::Check::CLI
  include Common

  option :groupname,
         description: 'Name of the AutoScaling group',
         short: '-g GROUP_NAME',
         long: '--groupname GROUP_NAME',
         required: true

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (such as us-east-1).',
         default: 'us-east-1'

  option :warn,
         short: '-w COUNT',
         long: '--warn COUNT',
         proc: proc(&:to_i),
         default: 15

  option :crit,
         short: '-c COUNT',
         long: '--crit COUNT',
         proc: proc(&:to_i),
         default: 25

  def instance_count
    client = Aws::AutoScaling::Client.new
    resp = client.describe_auto_scaling_groups(
      auto_scaling_group_names: [config[:groupname]]
    ).to_h
    instances = []
    resp[:auto_scaling_groups].each do |g|
      g[:instances].each do |i|
        if i[:lifecycle_state] == 'InService' && i[:health_status] == 'Healthy'
          instances << i[:instance_id]
        end
      end
    end
    instances.length
  rescue StandardError => e
    critical "There was an error reaching AWS - #{e.message}"
  end

  def run
    count = instance_count
    msg_prefix = "#{count} instances running for ASG [ #{config[:groupname]} ]"
    if count >= config[:crit]
      critical "#{msg_prefix} - critical threshold #{config[:crit]}"
    elsif count >= config[:warn]
      warning "#{msg_prefix} - warning threshold #{config[:warn]}, critical threshold #{config[:crit]}"
    else
      ok msg_prefix
    end
  end
end
