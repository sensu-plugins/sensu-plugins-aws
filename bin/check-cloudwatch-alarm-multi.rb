#! /usr/bin/env ruby
#
# check-cloudwatch-alarm-multi
#
# DESCRIPTION:
#   This plugin raise a critical if one of cloud watch alarms are in given state, and a critical for
#   each alarm in given state.
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
#   ./check-cloudwatch-alarm-multi --exclude-alarms "CPUAlarmLow"
#   ./check-cloudwatch-alarm-multi --region eu-west-1 --exclude-alarms "CPUAlarmLow"
#
# NOTES:
#
# LICENSE:
#   Copyright (c) 2017, Steven Ayers, sayers@equalexperts.com
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

  option :exclude_alarms,
         description: 'Exclude alarms',
         short: '-e EXCLUDE_ALARMS',
         long: '--exclude-alarms',
         proc: proc { |a| a.split(',') },
         default: []

  def run
    client = Aws::CloudWatch::Client.new
    options = { state_value: config[:state] }
    alarms = client.describe_alarms(options).metric_alarms

    if alarms.empty?
      ok "No alarms in '#{config[:state]}' state"
    end

    config[:exclude_alarms].each do |x|
      alarms.delete_if { |alarm| alarm.alarm_name.match(x) }
    end

    alarm_names = alarms.map(&:alarm_name)

    alarm_names.each do |alarm|
      send_critical("check_cloudwatch_alarm_#{alarm}", "#{alarm} in '#{config[:state]}' state")
    end

    critical "#{alarms.size} in '#{config[:state]}' state: #{alarm_names.join(',')}" unless alarms.empty?
  rescue StandardError => e
    puts "Error: exception: #{e}"
    critical
  end

  def sensu_client_socket(msg)
    u = UDPSocket.new
    u.send(msg + "\n", 0, '127.0.0.1', 3030)
  end

  def send_critical(check_name, msg)
    d = { 'name' => check_name, 'status' => 2, 'output' => msg, 'handlers' => config[:handlers] }
    sensu_client_socket d.to_json
  end
end
