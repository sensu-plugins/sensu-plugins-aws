#! /usr/bin/env ruby
#
# asg-metrics
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
#
#
# NOTES:
#   Returns latency statistics by default.  You can specify any valid ASG metric type, see
#   https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/as-metricscollected.html
#
# LICENSE:
#   Peter Hoppe <peter.hoppe.extern@bertelsmann.de>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/metric/cli'
require 'aws-sdk'
require 'sensu-plugins-aws'
require 'time'

class ASGMetrics < Sensu::Plugin::Metric::CLI::Graphite
  include Common
  option :asgname,
         description: 'Name of the Auto Scaling Group',
         short: '-n ASG_NAME',
         long: '--name ASG_NAME'

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME'

  option :fetch_age,
         description: 'How long ago to fetch metrics for',
         short: '-f AGE',
         long: '--fetch_age',
         default: 60,
         proc: proc(&:to_i)

  option :metric,
         description: 'Metric to fetch',
         short: '-m METRIC',
         long: '--metric',
         default: 'GroupInServiceInstances'

  option :statistic,
         description: 'Statistic type',
         short: '-t STATISTIC',
         long: '--statistic',
         default: 'Sum'

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

  def asg
    @asg = Aws::AutoScaling::Client.new
  end

  def cloud_watch_metric(metric_name, value, asg_name)
    cloud_watch.get_metric_statistics(
      namespace: 'AWS/AutoScaling',
      metric_name: metric_name,
      dimensions: [
        {
          name: 'AutoScalingGroupName',
          value: asg_name
        }
      ],
      statistics: [value],
      start_time: config[:end_time] - config[:period],
      end_time: config[:end_time],
      period: config[:period]
    )
  end

  def print_statistics(asg_name, statistics)
    result = {}
    statistics.each do |key, static|
      r = cloud_watch_metric(key, static, asg_name)
      keys =
        if config[:scheme].nil?
          []
        else
          [config[:scheme]]
        end
      keys.concat ['AutoScalingGroup', asg_name.tr(' ', '_'), key, static]

      result[keys.join('.')] = r[:datapoints].first unless r[:datapoints].first.nil?
    end
    result.each do |key, value|
      output key.downcase.to_s, value[config[:statistic].downcase], value[:timestamp].to_i
    end
  end

  def run
    statistic = {
      'GroupMinSize' => config[:statistic],
      'GroupMaxSize' => config[:statistic],
      'GroupDesiredCapacity' => config[:statistic],
      'GroupInServiceInstances' => config[:statistic],
      'GroupPendingInstances' => config[:statistic],
      'GroupStandbyInstances' => config[:statistic],
      'GroupTerminatingInstances' => config[:statistic],
      'GroupTotalInstances' => config[:statistic]
    }

    begin
      if config[:asgname].nil?
        asg.describe_auto_scaling_groups.auto_scaling_groups.each do |autoscalinggroup|
          print_statistics(autoscalinggroup.auto_scaling_group_name, statistic)
        end
      else
        print_statistics(config[:asgname], statistic)
      end
      ok
    end
  end
end
