#! /usr/bin/env ruby
#
# metrics-waf
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
#
# LICENSE:
#   Zubov Yuri <yury.zubau@gmail.com> sponsored by Actility, https://www.actility.com
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/metric/cli'
require 'aws-sdk'
require 'sensu-plugins-aws'
require 'time'

class WafMetrics < Sensu::Plugin::Metric::CLI::Generic
  include CloudwatchCommon

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: 'aws.waf'

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default: 'us-east-1'

  option :metric,
         description: 'Metric to fetch',
         short: '-m METRIC',
         long: '--metric',
         required: false,
         in: %w[AllowedRequests BlockedRequests CountedRequests PassedRequests]

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

  def print_statistics(statistics, config)
    statistics.each do |key, stats|
      r = client.get_metric_statistics(metrics_request(config).merge(metric_name: key, statistics: [stats]))
      keys = [config[:scheme]]
      keys.concat([key, stats])
      unless r[:datapoints].first.nil?
        output metric_name: keys.join('.'), value: r[:datapoints].first[stats.downcase]
      end
    end
  end

  def run
    statistic = {
      'AllowedRequests' => 'Sum',
      'BlockedRequests' => 'Sum',
      'CountedRequests' => 'Sum',
      'PassedRequests' => 'Sum'
    }

    unless config[:metric].nil?
      statistic.select! { |key, _| key == config[:metric] }
    end

    new_config = config.clone
    new_config[:namespace] = 'WAF'
    new_config[:dimensions] = [
      {
        name: 'WebACL',
        value: 'SecurityAutomationsMaliciousRequesters'
      },
      {
        name: 'Rule',
        value: 'ALL'
      }
    ]

    print_statistics(statistic, new_config)
    ok
  end
end
