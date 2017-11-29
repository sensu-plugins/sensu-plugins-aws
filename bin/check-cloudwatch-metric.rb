#! /usr/bin/env ruby
#
# check-cloudwatch-metric
#
# DESCRIPTION:
#   This plugin retrieves the value of a cloudwatch metric and triggers
#   alarms based on the thresholds specified
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
#   ./check-cloudwatch-metric -m CPUUtilization -d InstanceId=i-12345678,AvailabilityZone=us-east-1a -c 90
#
# NOTES:
#
# LICENSE:
#   Andrew Matheny
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugins-aws'
require 'sensu-plugin/check/cli'
require 'aws-sdk'

class CloudWatchMetricCheck < Sensu::Plugin::Check::CLI
  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default: 'us-east-1'

  option :namespace,
         description: 'CloudWatch namespace for metric',
         short: '-n NAME',
         long: '--namespace NAME',
         default: 'AWS/EC2'

  option :metric_name,
         description: 'Metric name',
         short: '-m NAME',
         long: '--metric NAME',
         required: true

  option :dimensions,
         description: 'Comma delimited list of DimName=Value',
         short: '-d DIMENSIONS',
         long: '--dimensions DIMENSIONS',
         proc: proc { |d| CloudwatchCommon.parse_dimensions d },
         default: []

  option :period,
         description: 'CloudWatch metric statistics period. Must be a multiple of 60',
         short: '-p N',
         long: '--period SECONDS',
         default: 60,
         proc: proc(&:to_i)

  option :statistics,
         short: '-s N',
         long: '--statistics NAME',
         default: 'Average',
         description: 'CloudWatch statistics method'

  option :unit,
         short: '-u UNIT',
         long: '--unit UNIT',
         description: 'CloudWatch metric unit'

  option :critical,
         description: 'Trigger a critical when value is over VALUE',
         short: '-c VALUE',
         long: '--critical VALUE',
         proc: proc(&:to_f),
         required: true

  option :warning,
         description: 'Trigger a warning when value is over VALUE',
         short: '-w VALUE',
         long: '--warning VALUE',
         proc: proc(&:to_f)

  option :compare,
         description: 'Comparision operator for threshold: equal, not, greater, less',
         short: '-o OPERATION',
         long: '--operator OPERATION',
         default: 'greater'

  option :no_data_ok,
         short: '-O',
         long: '--allow-no-data',
         description: 'Returns ok if no data is returned from the metric',
         boolean: true,
         default: false

  include CloudwatchCommon

  def self.parse_dimensions(dimension_string)
    dimension_string.split(',')
                    .collect { |d| d.split '=' }
                    .collect { |a| { name: a[0], value: a[1] } }
  end

  def dimension_string
    config[:dimensions].map { |d| "#{d[:name]}=#{d[:value]}" }.join('&')
  end

  def metric_desc
    "#{config[:namespace]}-#{config[:metric_name]}(#{dimension_string})"
  end

  def run
    check config
  end
end
