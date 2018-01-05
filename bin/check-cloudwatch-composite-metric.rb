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
         description: 'Trigger a critical when value is over VALUE as a Percent',
         short: '-c VALUE',
         long: '--critical VALUE',
         proc: proc(&:to_f),
         required: true

  option :warning,
         description: 'Trigger a warning when value is over VALUE as a Percent',
         short: '-w VALUE',
         long: '--warning VALUE',
         proc: proc(&:to_f)

  option :compare,
         description: 'Comparision operator for threshold: equal, not, greater, less',
         short: '-o OPERATION',
         long: '--operator OPERATION',
         default: 'greater'

  option :numerator_default,
         long: '--numerator-default DEFAULT',
         description: 'Default for numerator if no data is returned for metric',
         proc: proc(&:to_f)

  option :no_denominator_data_ok,
         long: '--allow-no-denominator-data',
         description: 'Returns ok if no data is returned from denominator metric',
         boolean: true,
         default: false

  option :zero_denominator_data_ok,
         long: '--allow-zero-denominator-data',
         description: 'Returns ok if denominator metric is zero',
         boolean: true,
         default: false

  option :no_data_ok,
         short: '-O',
         long: '--allow-no-data',
         description: 'Returns ok if no data is returned from either metric',
         boolean: true,
         default: false
  include CloudwatchCommon

  def metric_desc
    "#{config[:namespace]}-#{config[:numerator_metric_name]}/#{config[:denominator_metric_name]}(#{dimension_string})"
  end

  def numerator_data(metric_payload)
    if resp_has_no_data(metric_payload, config[:statistics])
      # If the numerator response has no data in it, see if there was a predefined default.
      # If there is no predefined default it will return nil
      config[:numerator_default]
    else
      read_value(metric_payload, config[:statistics]).to_f
    end
  end

  # rubocop:disable Style/GuardClause
  def composite_check
    numerator_metric_resp = get_metric(config[:numerator_metric_name])
    denominator_metric_resp = get_metric(config[:denominator_metric_name])

    ## If the numerator is empty, then we see if there is a default. If there is a default
    ## then we will pretend the numerator _isnt_ empty. That is
    ## if empty but there is no default this will be true. If it is empty and there is a default
    ## this will be false (i.e. there is data, following standard of dealing in the negative here)
    no_num_data = numerator_data(numerator_metric_resp).nil?
    no_den_data = resp_has_no_data(denominator_metric_resp, config[:statistics])
    no_data = no_num_data || no_den_data

    # no data in numerator or denominator this is to keep backwards compatibility
    if no_data && config[:no_data_ok]
      return :ok, "#{metric_desc} returned no data but that's ok"
    elsif no_den_data && config[:no_denominator_data_ok]
      return :ok, "#{config[:denominator_metric_name]} returned no data but that's ok"
    elsif no_data ## This is legacy case
      return :unknown, "#{metric_desc} could not be retrieved"
    end

    ## Now both the denominator and numerator have data (or a valid default)
    denominator_value = read_value(denominator_metric_resp, config[:statistics]).to_f
    if denominator_value.zero? && config[:zero_denominator_data_ok]
      return :ok, "#{metric_desc}: denominator value is zero but that's ok"
    elsif denominator_value.zero?
      return :unknown, "#{metric_desc}: denominator value is zero"
    end

    ## We already checked if this value is nil so we know its not
    numerator_value = numerator_data(numerator_metric_resp)
    value = (numerator_value / denominator_value * 100).to_i
    base_msg = "#{metric_desc} is #{value}: comparison=#{config[:compare]}"

    if compare(value, config[:critical], config[:compare])
      return :critical, "#{base_msg} threshold=#{config[:critical]}"
    elsif config[:warning] && compare(value, config[:warning], config[:compare])
      return :warning,  "#{base_msg} threshold=#{config[:warning]}"
    else
      threshold = config[:warning] || config[:critical]
      return :ok, "#{base_msg}, will alarm at #{threshold}"
    end
  end
  # rubocop:enable Style/GuardClause

  def run
    status, msg = composite_check
    if respond_to?(status)
      send(status, msg)
    else
      unknown 'unknown exit status called'
    end
  end
end
