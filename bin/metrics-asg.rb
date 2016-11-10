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
#   http://http://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/as-metricscollected.html
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
         long: '--name ASG_NAME',
         required: true

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: ''

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
         description: 'Statistics type',
         short: '-t STATISTIC',
         long: '--statistic',
         default: ''

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default: ENV['AWS_REGION']

  def cloud_watch
    @cloud_watch = Aws::CloudWatch::Client.new
  end

  def run
    if config[:statistic] == ''
      default_statistic_per_metric = {
        'GroupMinSize' => 'Sum',
        'GroupMaxSize' => 'Sum',
        'GroupDesiredCapacity' => 'Sum',
        'GroupInServiceInstances' => 'Sum',
        'GroupPendingInstances' => 'Sum',
        'GroupStandbyInstances' => 'Sum',
        'GroupTerminatingInstances' => 'Sum',
        'GroupTotalInstances' => 'Sum'
      }
      statistic = default_statistic_per_metric[config[:metric]]
    else
      statistic = config[:statistic]
    end

    begin
      et = Time.now - config[:fetch_age]
      st = et - 60
      options = {
        namespace: 'AWS/AutoScaling',
        metric_name: config[:metric],
        dimensions: [
          {
            name: 'AutoScaling',
            value: config[:asgname]
          }
        ],
        statistics: [statistic],
        start_time: st.iso8601,
        end_time: et.iso8601,
        period: 60
      }


      result = cloud_watch.get_metric_statistics(options)
      data = result[:datapoints][0]
      unless data.nil?
        # We only return data when we have some to return
        graphitepath = config[:scheme]
        if config[:scheme] == ''
          graphitepath = "#{config[:asgname]}.#{config[:metric].downcase}"
        end
        print statistic.downcase.to_sym
        output graphitepath, data[statistic.downcase.to_sym], data[:timestamp].to_i
      end
    rescue => e
      critical "Error: exception: #{e}"
    end
    ok
  end
end
