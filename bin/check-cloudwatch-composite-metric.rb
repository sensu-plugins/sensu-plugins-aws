#! /usr/bin/env ruby
#
# check-cloudwatch-composite-metric
#
# DESCRIPTION:
#   This plugin retrieves a couple of values of two cloudwatch metrics,
#   computes a percentage value based on the numerator metric and the denomicator metric
#   and triggers alarms based on the thresholds specified.
#   This plugin is an extension to the Andrew Matheny's check-cloudwatch-metric plugin
#   and uses the CloudwatchCommon lib, extended as well.
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
#   ./check-cloudwatch-composite-metric.rb --namespace AWS/ELB -N HTTPCode_Backend_4XX -D RequestCount --dimensions LoadBalancerName=test-elb --period 60 --statistics Maximum --operator equal --critical 0
#
# NOTES:
#
# LICENSE:
#   Cornel Foltea
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugins-aws'
require 'sensu-plugin/check/cli'
require 'aws-sdk'

class CloudWatchCompositeMetricCheck < Sensu::Plugin::Check::CLI
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

  option :numerator_metric_name,
         description: 'Numerator metric name',
         short: '-N NAME',
         long: '--numerator-metric NAME',
         required: true

  option :denominator_metric_name,
         description: 'Denominator metric name',
         short: '-D NAME',
         long: '--denominator-metric NAME',
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
         description: 'Trigger a critical when value is over VALUE',
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

  def metric_desc
    "#{config[:namespace]}-#{config[:numerator_metric_name]}/#{config[:denominator_metric_name]}(#{dimension_string})"
  end

  def run
    composite_check config
  end
end
