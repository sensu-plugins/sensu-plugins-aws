#! /usr/bin/env ruby
#
# check-elb-latency
#
#
# DESCRIPTION:
#   This plugin checks the health of an Amazon Elastic Load Balancer.
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: aws-sdk-v1
#   gem: sensu-plugin
#
# USAGE:
#   Warning if any load balancer's latency is over 1 second, critical if over 3 seconds.
#   check-elb-latency --warning-over 1 --critical-over 3
#
#   Critical if "app" load balancer's latency is over 5 seconds, maximum of last one hour
#   check-elb-latency --elb-names app --critical-over 5 --statistics maximum --period 3600
#
# NOTES:
#
# LICENSE:
#   Copyright 2014 github.com/y13i
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'aws-sdk-v1'

class CheckELBLatency < Sensu::Plugin::Check::CLI
  option :aws_access_key,
         short:       '-a AWS_ACCESS_KEY',
         long:        '--aws-access-key AWS_ACCESS_KEY',
         description: "AWS Access Key. Either set ENV['AWS_ACCESS_KEY'] or provide it as an option",
         default:     ENV['AWS_ACCESS_KEY']

  option :aws_secret_access_key,
         short:       '-k AWS_SECRET_KEY',
         long:        '--aws-secret-access-key AWS_SECRET_KEY',
         description: "AWS Secret Access Key. Either set ENV['AWS_SECRET_KEY'] or provide it as an option",
         default:     ENV['AWS_SECRET_KEY']

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

  option :statistics,
         short:       '-S N',
         long:        '--statistics NAME',
         default:     :average,
         proc:        proc { |a| a.downcase.intern },
         description: 'CloudWatch statistics method'

  %w(warning critical).each do |severity|
    option :"#{severity}_over",
           long:        "--#{severity}-over SECONDS",
           proc:        proc(&:to_f),
           description: "Trigger a #{severity} if latancy is over specified seconds"
  end

  def aws_config
    { access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key],
      region: config[:aws_region]
    }
  end

  def elb
    @elb ||= AWS::ELB.new aws_config
  end

  def cloud_watch
    @cloud_watch ||= AWS::CloudWatch.new aws_config
  end

  def elbs
    return @elbs if @elbs
    @elbs = elb.load_balancers.to_a
    @elbs.select! { |elb| config[:elb_names].include? elb.name } if config[:elb_names]
    @elbs
  end

  def latency_metric(elb_name)
    cloud_watch.metrics.with_namespace('AWS/ELB').with_metric_name('Latency').with_dimensions(name: 'LoadBalancerName', value: elb_name).first
  end

  def statistics_options
    {
      start_time: config[:end_time] - config[:period],
      end_time:   config[:end_time],
      statistics: [config[:statistics].to_s.capitalize],
      period:     config[:period]
    }
  end

  def latest_value(metric)
    metric.statistics(statistics_options.merge unit: 'Seconds').datapoints.sort_by { |datapoint| datapoint[:timestamp] }.last[config[:statistics]]
  end

  def flag_alert(severity, message)
    @severities[severity] = true
    @message += message
  end

  def check_latency(elb)
    metric        = latency_metric elb.name
    metric_value  = begin
                      latest_value metric
                    rescue
                      0
                    end

    @severities.keys.each do |severity|
      threshold = config[:"#{severity}_over"]
      next unless threshold
      next if metric_value < threshold
      flag_alert severity,
                 "; #{elbs.size == 1 ? nil : "#{elb.inspect}'s"} Latency is #{sprintf '%.3f', metric_value} seconds. (expected lower than #{sprintf '%.3f', threshold})"
      break
    end
  end

  def run
    @message = if elbs.size == 1
                 elbs.first.inspect
               else
                 "#{elbs.size} load balancers total"
               end

    @severities = {
      critical: false,
      warning:  false
    }

    elbs.each { |elb| check_latency elb }

    @message += "; (#{config[:statistics].to_s.capitalize} within #{config[:period]} seconds "
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
