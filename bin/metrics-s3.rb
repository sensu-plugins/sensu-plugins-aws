#! /usr/bin/env ruby
#
# s3-metrics
#
# DESCRIPTION:
#   Gets S3 metrics from CloudWatch and puts them in Graphite for longer term storage
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
#   gem: sensu-plugins-aws
#
# USAGE:
#   metrics-s3.rb -r us-west-2
#
# NOTES:
#
# LICENSE:
#   Copyright (c) 2015, Olivier Bazoud, olivier.bazoud@gmail.com
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/metric/cli'
require 'aws-sdk'
require 'sensu-plugins-aws'

class S3Metrics < Sensu::Plugin::Metric::CLI::Graphite
  include Common

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default: 'us-east-1'

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: 'sensu.aws.s3.buckets'

  def bucket_size(size_size = 'bytes'); end

  def run
    begin
      s3 = Aws::S3::Client.new(aws_config)
      list_buckets = s3.list_buckets

      cw = Aws::CloudWatch::Client.new(aws_config)

      now = Time.now
      # TODO: come back and refactor this
      list_buckets.buckets.each do |bucket| # rubocop:disable Metrics/BlockLength)
        bucket_name = bucket.name.tr('.', '_')
        bucket_size_bytes = cw.get_metric_statistics(
          namespace: 'AWS/S3',
          metric_name: 'BucketSizeBytes',
          dimensions: [
            {
              name: 'BucketName',
              value: bucket.name
            }, {
              name: 'StorageType',
              value: 'StandardStorage'
            }
          ],
          start_time: (now.utc - 24 * 60 * 60).iso8601,
          end_time: now.utc.iso8601,
          period: 24 * 60 * 60,
          statistics: ['Average'],
          unit: 'Bytes'
        )
        output "#{config[:scheme]}.#{bucket_name}.bucket_size_bytes", bucket_size_bytes[:datapoints][0].average, now.to_i unless bucket_size_bytes[:datapoints][0].nil?

        number_of_objects = cw.get_metric_statistics(
          namespace: 'AWS/S3',
          metric_name: 'NumberOfObjects',
          dimensions: [
            {
              name: 'BucketName',
              value: bucket.name
            }, {
              name: 'StorageType',
              value: 'AllStorageTypes'
            }
          ],
          start_time: (now.utc - 24 * 60 * 60).iso8601,
          end_time: now.utc.iso8601,
          period: 24 * 60 * 60,
          statistics: ['Average'],
          unit: 'Count'
        )
        output "#{config[:scheme]}.#{bucket_name}.number_of_objects", number_of_objects[:datapoints][0].average, now.to_i unless number_of_objects[:datapoints][0].nil?
      end
    rescue StandardError => e
      critical "Error: exception: #{e}"
    end
    ok
  end
end
