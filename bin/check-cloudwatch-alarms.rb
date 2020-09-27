#! /usr/bin/env ruby
#
# check-cloudwatch-alarms
#
# DESCRIPTION:
#   This plugin raise a critical if one of cloud watch alarms are in given state.
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
#   ./check-cloudwatch-alarms --name-prefix "staging"
#   ./check-cloudwatch-alarms --exclude-alarms "CPUAlarmLow"
#   ./check-cloudwatch-alarms --aws-region eu-west-1 --exclude-alarms "CPUAlarmLow"
#
# NOTES:
#
# LICENSE:
#   Copyright (c) 2017, Olivier Bazoud, olivier.bazoud@gmail.com
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'sensu-plugins-aws/common'
require 'aws-sdk'

class CloudWatchCheck < Sensu::Plugin::Check::CLI
  include Common

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default: 'us-east-1'

  option :state,
         description: 'State of the alarm',
         short: '-s STATE',
         long: '--state STATE',
         default: 'ALARM'

  option :name_prefix,
         description: 'Alarm name prefix',
         short: '-p NAME_PREFIX',
         long: '--name-prefix NAME_PREFIX',
         default: ''

  option :exclude_alarms,
         description: 'Exclude alarms',
         short: '-e EXCLUDE_ALARMS',
         long: '--exclude-alarms',
         proc: proc { |a| a.split(',') },
         default: []

  def run
    client = Aws::CloudWatch::Client.new

    options = { state_value: config[:state] }

    unless config[:name_prefix].empty?
      options[:alarm_name_prefix] = config[:name_prefix]
    end

    alarms = client.describe_alarms(options).metric_alarms

    if alarms.empty?
      ok "No alarms in '#{config[:state]}' state"
    end

    config[:exclude_alarms].each do |x|
      alarms.delete_if { |alarm| alarm.alarm_name.match(x) }
    end

    critical "#{alarms.size} in '#{config[:state]}' state: #{alarms.map(&:alarm_name).join(',')}" unless alarms.empty?

    ok 'everything looks good'
  rescue StandardError => e
    puts "Error: exception: #{e}"
    critical
  end
end
