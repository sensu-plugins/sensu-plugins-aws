#! /usr/bin/env ruby
#
# elasticache-metrics
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

class ElasticMetrics < Sensu::Plugin::Metric::CLI::Graphite
  include Common
  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: ''

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

  def elasticaches
    @elasticaches = Aws::ElastiCache::Client.new
  end

  def cloud_watch_metric(metric_name, value, cache_cluster_id)
    cloud_watch.get_metric_statistics(
      namespace: 'AWS/ElastiCache',
      metric_name: metric_name,
      dimensions: [
        {
          name: 'CacheClusterId',
          value: cache_cluster_id
        }
      ],
      statistics: [value],
      start_time: config[:end_time] - config[:period],
      end_time: config[:end_time],
      period: config[:period]
    )
  end

  def print_statistics(cache_cluster_id, statistics)
    result = {}
    statistics.each do |key, static|
      r = cloud_watch_metric(key, static, cache_cluster_id)
      result['elasticache.' + cache_cluster_id + '.' + key] = r[:datapoints][0] unless r[:datapoints][0].nil?
    end
    return if result.nil?
    result.each do |key, value|
      output key.downcase.to_s, value.average, value[:timestamp].to_i
    end
  end

  def run
    # TODO: come back and refactor
    elasticaches.describe_cache_clusters.cache_clusters.each do |elasticache| # rubocop:disable Metrics/BlockLength)
      if elasticache.engine.include? 'redis'
        if config[:statistic] == ''
          default_statistic_per_metric = {
            'BytesUsedForCache' => 'Average',
            'CacheHits' => 'Average',
            'CacheMisses' => 'Average',
            'CurrConnections' => 'Average',
            'Evictions' => 'Average',
            'HyperLogLogBasedCmds' => 'Average',
            'NewConnections' => 'Average',
            'Reclaimed' => 'Average',
            'ReplicationBytes' => 'Average',
            'ReplicationLag' => 'Average',
            'SaveInProgress' => 'Average'
          }
          statistic = default_statistic_per_metric
        else
          statistic = config[:statistic]
        end
        print_statistics(elasticache.cache_cluster_id, statistic)
      elsif elasticache.engine.include? 'memcached'
        if config[:statistic] == ''
          default_statistic_per_metric = {
            'BytesReadIntoMemcached' => 'Average',
            'BytesUsedForCacheItems' => 'Average',
            'BytesWrittenOutFromMemcached' => 'Average',
            'CasBadval' => 'Average',
            'CasHits' => 'Average',
            'CasMisses' => 'Average',
            'CmdFlush' => 'Average',
            'CmdGet' => 'Average',
            'CmdSet' => 'Average',
            'CurrConnections' => 'Average',
            'CurrItems' => 'Average',
            'DecrHits' => 'Average',
            'DecrMisses' => 'Average',
            'DeleteHits' => 'Average',
            'DeleteMisses' => 'Average',
            'Evictions' => 'Average',
            'GetHits' => 'Average',
            'GetMisses' => 'Average',
            'IncrHits' => 'Average',
            'IncrMisses' => 'Average',
            'Reclaimed' => 'Average'
          }
          statistic = default_statistic_per_metric
        else
          statistic = config[:statistic]
        end
        print_statistics(elasticache.cache_cluster_id, statistic)
      end
    end
    exit
  end
end
