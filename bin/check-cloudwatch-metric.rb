#! /usr/bin/env ruby
#
# check-cloudwatch-alarm
#
# DESCRIPTION:
#   This plugin retrieves the value of a cloudwatch metric and triggers
#   alarms based on the threshold's specified
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
#   ./check-cloudwatch-metric -n CPUUtilization -d InstanceId=i-12345678,AvailabilityZone=us-east-1a -c 90
#
# NOTES:
#
# LICENSE:
#   Andrew Matheny
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'aws-sdk'

class CloudWatchMetricCheck < Sensu::Plugin::Check::CLI

  option :namespace,
          description: 'CloudWatch namespace for metric',
          short: '-n NAME',
          long: '--namespace NAME',
          default: "AWS/EC2"

  option :metric_name,
          description: 'Metric name',
          short: '-m NAME',
          long: '--metric NAME',
          required: true

  option :dimensions,
          description: 'Comma delimited list of DimName=Value',
          short: '-d DIMENSIONS',
          long: '--dimensions DIMENSIONS',
          proc: proc { |d| CloudWatchMetricCheck.parse_dimensions d },
          default: ''

  option :period,
          description: 'CloudWatch metric statistics period. Must be a multiple of 60',
          short:       '-p N',
          long:        '--period SECONDS',
          default:     60,
          proc:        proc(&:to_i)

  option :statistics,
          short:       '-s N',
          long:        '--statistics NAME',
          default:     ["Average"],
          proc: proc { |s| [s] },
          description: 'CloudWatch statistics method'

  option :unit,
          short:       '-u UNIT',
          long:        '--unit UNIT',
          description: 'CloudWatch metric unit'

  option :critical,
          description: 'Trigger a critical when value is over VALUE',
          short: '-c VALUE',
          long: '--critical VALUE',
          proc:        proc(&:to_f),
          required: true

  option :warning,
          description: 'Trigger a critical when value is over VALUE',
          short: '-w VALUE',
          long: '--warning VALUE',
          proc: proc(&:to_f)

  def self.parse_dimensions(dimension_string)
    dimension_string.split(',')
      .collect { |d| d.split '=' }
      .collect { |a| { name: a[0], value: a[1] } }
  end

  def dimension_string
    config[:dimensions].map{|d| "#{d[:name]}=#{d[:value]}"}.join('&')
  end

  def client
    @cloud_watch ||= Aws::CloudWatch::Client.new
  end

  def metric_desc
    @metric_desc ||= "#{config[:namespace]}-#{config[:metric_name]}(#{dimension_string})"
  end

  def run
    critical_threshold = config.delete(:critical)
    warning_threshold = config.delete(:warning)

    config[:start_time] = Time.now - config[:period]
    config[:end_time] = Time.now

    resp = client.get_metric_statistics(config)
    if resp == nil or resp.datapoints == nil or resp.datapoints.length == 0
      unknown "#{metric_desc} could not be retrieved"
    end

    value = resp.datapoints[0].send(config[:statistics][0].downcase)

    if not value
      unknown "#{metric_desc} could not be retrieved"
    end
    base_msg = "#{metric_desc} is #{value} which is "
    if value >= critical_threshold
      critical "#{base_msg} greater than #{critical_threshold}"
    elsif warning_threshold and value >= warning_threshold
      warning "#{base_msg} greater than #{warning_threshold}"
    else
      ok "#{base_msg} good"
    end
  end
end
