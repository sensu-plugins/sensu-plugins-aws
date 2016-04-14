#! /usr/bin/env ruby
#
# metrics-ses
#
# DESCRIPTION:
#   Lists SES send statistics
#
# OUTPUT:
#   metric data
#
# DEPENDENCIES:
#   gem: aws-sdk
#   gem: sensu-plugin
#
# USAGE:
#   metrics-ses.rb -r us-west-2
#
#   This will list out the statistics for the most recent 15 minutes from SES
#
# NOTES:
#
# LICENSE:
#   Brandon Smith <freedom@reardencode.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.

require 'sensu-plugins-aws'
require 'sensu-plugin/metric/cli'
require 'aws-sdk'

class SesMetrics < Sensu::Plugin::Metric::CLI::Graphite
  include Common

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: 'sensu.aws.ses'

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default: 'us-east-1'

  def run
    ses = Aws::SES::Client.new(aws_config)
    begin
      response = ses.get_send_statistics

      unknown 'Empty response from AWS SES API' if response.empty? # Can this happen?
      unknown 'No data points from AWS SES API' if response.send_data_points.empty?

      data_point = response.send_data_points.sort_by(&:timestamp).last
      output config[:scheme] + '.bounces', data_point.bounces
      output config[:scheme] + '.rejects', data_point.rejects
      output config[:scheme] + '.complaints', data_point.complaints
      output config[:scheme] + '.delivery_attempts', data_point.delivery_attempts
    end
    ok
  end
end
