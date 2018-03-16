#! /usr/bin/env ruby
#
# cloudfront-metrics
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

class CloudFrontMetrics < Sensu::Plugin::Metric::CLI::Graphite
  include Common
  option :distribution_id,
         description: 'Distribution id of Cloudfront',
         short: '-d DISTRIBUTION_ID',
         long: '--distribution_id DISTRIBUTION_ID'

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: 'aws.cloudfront'

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default: 'us-east-1'

  option :metric,
         description: 'Metric to fetch',
         short: '-m METRIC',
         long: '--metric',
         in: %w[Requests BytesDownloaded BytesUploaded TotalErrorRate 4xxErrorRate 5xxErrorRate]

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
    @cloud_watch ||= Aws::CloudWatch::Client.new
  end

  def cloud_watch_metric(metric_name, value, distribution_id)
    cloud_watch.get_metric_statistics(
      namespace: 'AWS/CloudFront',
      metric_name: metric_name,
      dimensions: [
        {
          name: 'Region',
          value: 'Global'
        },
        {
          name: 'DistributionId',
          value: distribution_id
        }
      ],
      statistics: [value],
      start_time: config[:end_time] - config[:period],
      end_time: config[:end_time],
      period: config[:period]
    )
  end

  def distribution_list
    list_metrics = cloud_watch.list_metrics(
      namespace: 'AWS/CloudFront'
    ).metrics

    list_metrics = list_metrics.select { |e| e.metric_name == config[:metric] } unless config[:metric].nil?

    list_metrics.reduce(Set.new) do |result, item|
      result << item.dimensions.find { |element| element.name == 'DistributionId' }.value
    end
  end

  def print_statistics(distribution_id, statistics)
    statistics.each do |key, static|
      r = cloud_watch_metric(key, static, distribution_id)
      keys = [config[:scheme]]
      keys.concat [distribution_id, key, static]
      output(keys.join('.'), r[:datapoints].first[static.downcase]) unless r[:datapoints].first.nil?
    end
  end

  def run
    statistic = {
      'Requests' => 'Sum',
      'BytesDownloaded' => 'Sum',
      'BytesUploaded' => 'Sum',
      'TotalErrorRate' => 'Average',
      '4xxErrorRate' => 'Average',
      '5xxErrorRate' => 'Average'
    }

    unless config[:metric].nil?
      statistic.select! { |key, _| key == config[:metric] }
    end

    begin
      if config[:distribution_id].nil?
        distribution_list.each do |distribution|
          print_statistics(distribution, statistic)
        end
      else
        print_statistics(config[:distribution_id], statistic)
      end
      ok
    end
  end
end
