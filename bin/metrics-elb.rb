#! /usr/bin/env ruby
#
# elb-metrics
#
# DESCRIPTION:
#   Gets latency metrics from CloudWatch and puts them in Graphite for longer term storage
#
# OUTPUT:
#   metric-data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: aws-sdk
#   gem: sensu-plugin
#   gem: sensu-plugin-aws
#   gem: time
#
# USAGE:
#   #YELLOW
#
# NOTES:
#   Returns latency statistics by default.  You can specify any valid ELB metric type, see
#   http://docs.aws.amazon.com/AmazonCloudWatch/latest/DeveloperGuide/CW_Support_For_AWS.html#elb-metricscollected
#
#   By default fetches statistics from one minute ago.  You may need to fetch further back than this;
#   high traffic ELBs can sometimes experience statistic delays of up to 10 minutes.  If you experience this,
#   raising a ticket with AWS support should get the problem resolved.
#   As a workaround you can use eg -f 300 to fetch data from 5 minutes ago.
#
# LICENSE:
#   Copyright 2013 Bashton Ltd http://www.bashton.com/
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#   Updated by Peter Hoppe <peter.hoppe.extern@bertelsmann.de> 09.11.2016
#   Using aws sdk version 2

require 'sensu-plugin/metric/cli'
require 'aws-sdk'
require 'sensu-plugins-aws'
require 'time'

class ELBMetrics < Sensu::Plugin::Metric::CLI::Graphite
  include Common
  option :elbname,
         description: 'Name of the Elastic Load Balancer',
         short: '-n ELB_NAME',
         long: '--name ELB_NAME'

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: 'elb'

  option :fetch_age,
         description: 'How long ago to fetch metrics for',
         short: '-f AGE',
         long: '--fetch_age',
         default: 60,
         proc: proc(&:to_i)

  option :statistic,
         description: 'Statistics type',
         short: '-t STATISTIC',
         long: '--statistic',
         default: ''

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default: ENV['AWS_REGION']

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

  def cloud_watch
    @cloud_watch = Aws::CloudWatch::Client.new
  end

  def loadbalancer
    @loadbalancer = Aws::ElasticLoadBalancing::Client.new
  end

  def cloud_watch_metric(metric_name, value, load_balancer_name)
    cloud_watch.get_metric_statistics(
      namespace: 'AWS/ELB',
      metric_name: metric_name,
      dimensions: [
        {
          name: 'LoadBalancerName',
          value: load_balancer_name
        }
      ],
      statistics: [value],
      start_time: config[:end_time] - config[:fetch_age] - config[:period],
      end_time: config[:end_time] - config[:fetch_age],
      period: config[:period]
    )
  end

  def print_statistics(load_balancer_name, statistics)
    result = {}
    static_value = {}
    statistics.each do |key, static|
      r = cloud_watch_metric(key, static, load_balancer_name)
      keys = if config[:scheme] == ''
               []
             else
               [config[:scheme]]
             end
      keys.concat [load_balancer_name, key, static]
      metric_key = keys.join('.')

      static_value[metric_key] = static
      result[metric_key] = r[:datapoints][0] unless r[:datapoints][0].nil?
    end
    result.each do |key, value|
      output key.downcase.to_s, value[static_value[key].downcase], value[:timestamp].to_i
    end
  end

  def run
    if config[:statistic] == ''
      default_statistic_per_metric = {
        'Latency' => 'Average',
        'RequestCount' => 'Sum',
        'UnHealthyHostCount' => 'Average',
        'HealthyHostCount' => 'Average',
        'HTTPCode_Backend_2XX' => 'Sum',
        'HTTPCode_Backend_3XX' => 'Sum',
        'HTTPCode_Backend_4XX' => 'Sum',
        'HTTPCode_Backend_5XX' => 'Sum',
        'HTTPCode_ELB_4XX' => 'Sum',
        'HTTPCode_ELB_5XX' => 'Sum',
        'BackendConnectionErrors' => 'Sum',
        'SurgeQueueLength' => 'Maximum',
        'SpilloverCount' => 'Sum'
      }
      statistic = default_statistic_per_metric
    else
      statistic = config[:statistic]
    end

    begin
      if config[:elbname].nil?
        loadbalancer.describe_load_balancers.load_balancer_descriptions.each do |elb|
          print_statistics(elb.load_balancer_name, statistic)
        end
      else
        print_statistics(config[:elbname], statistic)
      end
      ok
    end
  end
end
