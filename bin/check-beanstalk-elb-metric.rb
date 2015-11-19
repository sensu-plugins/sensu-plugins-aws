#! /usr/bin/env ruby
#
# check-cloudwatch-alarm
#
# DESCRIPTION:
#   This plugin finds the desired ELB in a beanstalk environment and queries
#   for the requested cloudwatch metric for that ELB
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
#   ./check-beanstalk-elb-metric -e MyAppEnv -m Latency -c 100
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

class BeanstalkELBCheck < Sensu::Plugin::Check::CLI

  option :environment,
          description: 'Application environment name',
          short: '-e ENVIRONMENT_NAME',
          long: '--environment ENVIRONMENT_NAME',
          required: true

  option :elb_idx,
          description: 'Index of ELB.  Useful for multiple ELB environments',
          short: '-i ELB_NUM',
          long: '--elb-idx ELB_NUM',
          default: 0,
          proc: proc(&:to_i)

  option :metric,
          description: 'ELB CloudWatch Metric',
          short: '-m METRIC_NAME',
          long: '--metric METRIC_NAME',
          required: true

  option :period,
          description: 'CloudWatch metric statistics period. Must be a multiple of 60',
          short:       '-p N',
          long:        '--period SECONDS',
          default:     60,
          proc:        proc(&:to_i)

  option :statistics,
          short:       '-s N',
          long:        '--statistics NAME',
          default:     "Average",
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

  def cloud_watch
    @cloud_watch ||= Aws::CloudWatch::Client.new
  end

  def beanstalk
    @beanstalk ||= Aws::ElasticBeanstalk::Client.new
  end

  def metric_desc
    @metric_desc ||= "BeanstalkELB/#{config[:environment]}/#{elb_name}/#{config[:metric]}"
  end

  def elb_name
    @elb_name ||= beanstalk
      .describe_environment_resources({environment_name: config[:environment]})
      .environment_resources
      .load_balancers[config[:elb_idx]]
      .name
  end

  def metrics_request
    {
      namespace: "AWS/ELB",
      metric_name: config[:metric],
      dimensions: [
        {
          name: "LoadBalancerName",
          value: elb_name
        }
      ],
      start_time: Time.now - config[:period],
      end_time: Time.now,
      period: config[:period],
      statistics: [config[:statistics]],
      unit: config[:unit]
    }
  end

  def run
    resp = cloud_watch.get_metric_statistics(metrics_request)
    if resp == nil or resp.datapoints == nil or resp.datapoints.length == 0
      unknown "#{metric_desc} could not be retrieved"
    end

    value = resp.datapoints[0].send(config[:statistics].downcase)

    if not value
      unknown "#{metric_desc} could not be retrieved"
    end
    base_msg = "#{metric_desc} is #{value} which is"
    if value >= config[:critical]
      critical "#{base_msg} greater than #{config[:critical]}"
    elsif config[:warning] and value >= config[:warning]
      warning "#{base_msg} greater than #{config[:warning]}"
    else
      ok "#{base_msg} good"
    end
  end
end
