#! /usr/bin/env ruby
#
# metrics-alb
#
# DESCRIPTION:
#   Gets Application Load Balancer metrics from CloudWatch and puts them in
#   Graphite for longer term storage
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
#   By default fetches statistics from one minute ago.  You may need to fetch
#   further back than this; high traffic load balancers can sometimes
#   experience statistic delays of up to 10 minutes.  If you experience this,
#   raising a ticket with AWS support should get the problem resolved.
#   As a workaround you can use eg -f 300 to fetch data from 5 minutes ago.
#
# LICENSE:
#   Copyright 2018 Jonathan Ballet <jon@multani.info>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.

require 'sensu-plugin/metric/cli'
require 'aws-sdk'
require 'sensu-plugins-aws'
require 'time'

class ALBMetrics < Sensu::Plugin::Metric::CLI::Graphite
  include CloudwatchCommon

  option :albname,
         description: 'Name of the Application Load Balancer',
         short: '-n ALB_NAME',
         long: '--name ALB_NAME'

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: 'alb'

  option :fetch_age,
         description: 'How long ago to fetch metrics for',
         short: '-f AGE',
         long: '--fetch-age',
         default: 60,
         proc: proc(&:to_i)

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (defaults to the AWS_REGION variable)',
         default: ENV['AWS_REGION']

  option :end_time,
         short:       '-t TIME',
         long:        '--end-time TIME',
         default:     Time.now,
         proc:        proc { |a| Time.parse a },
         description: 'CloudWatch metric statistics end time'

  option :period,
         short:       '-p SECONDS',
         long:        '--period SECONDS',
         default:     60,
         proc:        proc(&:to_i),
         description: 'CloudWatch metric statistics period'

  def loadbalancer
    @loadbalancer = Aws::ElasticLoadBalancingV2::Client.new
  end

  def cloud_watch_metric(metric_name, value, load_balancer_name, alb_id)
    name = ['app', load_balancer_name, alb_id].join('/')
    client.get_metric_statistics(
      namespace: 'AWS/ApplicationELB',
      metric_name: metric_name,
      dimensions: [
        {
          name: 'LoadBalancer',
          value: name
        }
      ],
      statistics: [value],
      start_time: config[:end_time] - config[:fetch_age] - config[:period],
      end_time: config[:end_time] - config[:fetch_age],
      period: config[:period]
    )
  end

  def print_statistics(load_balancer_name, alb_id, statistics)
    result = {}
    static_value = {}
    statistics.each do |key, static|
      r = cloud_watch_metric(key, static, load_balancer_name, alb_id)
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
      output key, value[static_value[key].downcase], value[:timestamp].to_i
    end
  end

  def run
    statistics = {
      'ActiveConnectionCount'          => 'Sum',
      'ClientTLSNegotiationErrorCount' => 'Sum',
      'ConsumedLCUs'                   => 'Sum',
      'HTTPCode_ELB_4XX_Count'         => 'Sum',
      'HTTPCode_ELB_5XX_Count'         => 'Sum',
      'HTTPCode_Target_2XX_Count'      => 'Sum',
      'HTTPCode_Target_3XX_Count'      => 'Sum',
      'HTTPCode_Target_4XX_Count'      => 'Sum',
      'HTTPCode_Target_5XX_Count'      => 'Sum',
      'IPv6ProcessedBytes'             => 'Sum',
      'IPv6RequestCount'               => 'Sum',
      'NewConnectionCount'             => 'Sum',
      'ProcessedBytes'                 => 'Sum',
      'RejectedConnectionCount'        => 'Sum',
      'RequestCount'                   => 'Sum',
      'RuleEvaluations'                => 'Sum',
      'TargetConnectionErrorCount'     => 'Sum',
      'TargetResponseTime'             => 'Average',
      'TargetTLSNegotiationErrorCount' => 'Sum',

      # The following metrics have a different dimension than the others:
      # 'HealthyHostCount'               => 'Average',  # Dimension=TargetGroup+LoadBalancer
      # 'RequestCountPerTarget'          => 'Sum',      # Dimension=TargetGroup
      # 'UnHealthyHostCount'             => 'Average',  # Dimension=TargetGroup+LoadBalancer
    }

    begin
      loadbalancer.describe_load_balancers.load_balancers.each do |alb|
        next unless config[:albname].nil? || config[:albname] == alb.load_balancer_name
        alb_id = alb.load_balancer_arn.split(':').last.split('/').last
        print_statistics(alb.load_balancer_name, alb_id, statistics)
      end
    end
    ok
  end
end
