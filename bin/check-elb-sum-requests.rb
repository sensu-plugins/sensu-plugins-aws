#! /usr/bin/env ruby
#
# chwck-elb-sum-requests
#
# DESCRIPTION:
#   Check ELB Sum Requests by CloudWatch API.
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
#   Warning if any load balancer's sum request count is over 1000, critical if over 2000.
#   check-elb-sum-requests --warning-over 1000 --critical-over 2000
#
#   Critical if "app" load balancer's sum request count is over 10000, within last one hour
#   check-elb-sum-requests --elb-names app --critical-over 10000 --period 3600
#
# NOTES:
#
# LICENSE:
#   Copyright 2014 github.com/y13i
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'sensu-plugins-aws'
require 'aws-sdk'

class CheckELBSumRequests < Sensu::Plugin::Check::CLI
  include Common

  option :aws_region,
         short:       '-r AWS_REGION',
         long:        '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default:     'us-east-1'

  option :elb_names,
         short:       '-l N',
         long:        '--elb-names NAMES',
         proc:        proc { |a| a.split(/[,;]\s*/) },
         description: 'Load balancer names to check. Separated by , or ;. If not specified, check all load balancers'

  option :end_time,
         short:       '-t T',
         long:        '--end-time TIME',
         default:     Time.now,
         proc:        proc { |a| Time.parse a },
         description: 'CloudWatch metric statistics end time'

  option :period,
         short:       '-p N',
         long:        '--period SECONDS',
         default:     60,
         proc:        proc(&:to_i),
         description: 'CloudWatch metric statistics period'

  %w[warning critical].each do |severity|
    option :"#{severity}_over",
           long:        "--#{severity}-over COUNT",
           proc:        proc(&:to_f),
           description: "Trigger a #{severity} if sum requests is over specified count"
  end

  def elb
    @elb ||= Aws::ElasticLoadBalancing::Client.new(aws_config)
  end

  def cloud_watch
    @cloud_watch ||= Aws::CloudWatch::Client.new
  end

  def elbs
    return @elbs if @elbs
    @elbs = elb.describe_load_balancers.load_balancer_descriptions.to_a
    @elbs.select! { |elb| config[:elb_names].include? elb.load_balancer_name } if config[:elb_names]
    @elbs
  end

  def request_count_metric(elb_name)
    cloud_watch.get_metric_statistics(
      namespace: 'AWS/ELB',
      metric_name: 'RequestCount',
      dimensions: [
        {
          name: 'LoadBalancerName',
          value: elb_name
        }
      ],
      start_time: config[:end_time] - config[:period],
      end_time: config[:end_time],
      statistics: ['Sum'],
      period: config[:period]
    )
  end

  def latest_value(metric)
    metric.datapoints.sort_by { |datapoint| datapoint[:timestamp] }.last[:sum]
  end

  def flag_alert(severity, message)
    @severities[severity] = true
    @message += message
  end

  def check_sum_requests(elb)
    metric        = request_count_metric elb.load_balancer_name
    metric_value  = begin
                      latest_value metric
                    rescue StandardError
                      0
                    end

    @severities.each_key do |severity|
      threshold = config[:"#{severity}_over"]
      next unless threshold
      next if metric_value < threshold
      flag_alert severity,
                 "; #{elbs.size == 1 ? nil : "#{elb.load_balancer_name}'s"} Sum Requests is #{metric_value}. (expected lower than #{threshold})"
      break
    end
  end

  def run
    @message = if elbs.size == 1
                 elbs.first.load_balancer_name
               else
                 "#{elbs.size} load balancers total"
               end

    @severities = {
      critical: false,
      warning:  false
    }

    elbs.each { |elb| check_sum_requests elb }

    @message += "; (Sum within #{config[:period]} seconds "
    @message += "between #{config[:end_time] - config[:period]} to #{config[:end_time]})"

    if @severities[:critical]
      critical @message
    elsif @severities[:warning]
      warning @message
    else
      ok @message
    end
  end
end
