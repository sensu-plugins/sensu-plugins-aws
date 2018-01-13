#! /usr/bin/env ruby
#
# check-cloudwatch-alarm
#
# DESCRIPTION:
#   This plugin retrieves the state of a CloudWatch alarm. Can be configured
#   to trigger a warning or critical based on the result. Defaults to OK unless
#   alarm is missing
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
#   ./check-cloudwatch-alarm -n TestAlarm
#   ./check-cloudwatch-alarm -c Alarm,INSUFFICIENT_DATA -n TestAlarm
#   ./check-cloudwatch-alarm -c Alarm -w INSUFFICIENT_DATA -n TestAlarm
#
# NOTES:
#
# LICENSE:
#   Justin McCarty
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'aws-sdk'

class CloudWatchCheck < Sensu::Plugin::Check::CLI
  option :aws_access_key,
         short: '-a AWS_ACCESS_KEY',
         long: '--aws-access-key AWS_ACCESS_KEY',
         description: "AWS Access Key. Either set ENV['AWS_ACCESS_KEY'] or provide it as an option",
         default: ENV['AWS_ACCESS_KEY']

  option :aws_secret_access_key,
         short: '-k AWS_SECRET_KEY',
         long: '--aws-secret-access-key AWS_SECRET_KEY',
         description: "AWS Secret Access Key. Either set ENV['AWS_SECRET_KEY'] or provide it as an option",
         default: ENV['AWS_SECRET_KEY']

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default: 'us-east-1'

  option :name,
         description: 'Alarm name',
         short: '-n NAME',
         long: '--name NAME',
         default: ''

  option :critical,
         description: 'Critical List',
         short: '-c Criticals',
         long: '--critical',
         default: ''

  option :warning,
         description: 'Warning state threshold',
         short: '-w THRESHOLD',
         long: '--warning THRESHOLD',
         default: ''

  def aws_config
    { access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key],
      region: config[:aws_region] }
  end

  def run
    client = Aws::CloudWatch::Client.new aws_config

    options = { alarm_names: [config[:name]] }
    data = client.describe_alarms(options)

    if data.metric_alarms.empty?
      unknown 'Unable to find alarm'
    end

    message = "Alarm State: #{data.metric_alarms[0].state_value}"

    if config[:critical].upcase.split(',').include? data.metric_alarms[0].state_value
      critical message
    elsif config[:warning].upcase.split(',').include? data.metric_alarms[0].state_value
      warning message
    end

    ok message
  rescue StandardError => e
    puts "Error: exception: #{e}"
    critical
  end
end
