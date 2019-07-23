#! /usr/bin/env ruby
#
# reservation-utilization
#
# DESCRIPTION:
#   Gets Reservation Utilization of an AWS account.
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
#   metrics-reservation-utilization.rb
#
# NOTES:
#
# LICENSE:
#   Copyright (c) 2019, Nicolas Boutet amd3002@gmail.com
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/metric/cli'
require 'aws-sdk'
require 'sensu-plugins-aws'

class ReservationUtilizationMetrics < Sensu::Plugin::Metric::CLI::Graphite
  include Common

  option :from,
         short:       '-f TIME',
         long:        '--from TIME',
         default:     Time.now - 2 * 86_400, # start date cannot be after 2 days ago
         proc:        proc { |a| Time.parse a },
         description: 'The beginning of the time period that you want the usage and costs for (inclusive).'

  option :to,
         short:       '-t TIME',
         long:        '--to TIME',
         default:     Time.now,
         proc:        proc { |a| Time.parse a },
         description: 'The end of the time period that you want the usage and costs for (exclusive).'

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric.',
         short:       '-s SCHEME',
         long:        '--scheme SCHEME',
         default:     'sensu.aws.reservation_utilization'

  option :aws_region,
         short:       '-r AWS_REGION',
         long:        '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default:     'us-east-1'

  def run
    begin
      client = Aws::CostExplorer::Client.new(aws_config)

      reservation_utilization = client.get_reservation_utilization(
        time_period: {
          start: config[:from].strftime('%Y-%m-%d'),
          end: config[:to].strftime('%Y-%m-%d')
        }
      )

      reservation_utilization.utilizations_by_time.each do |time|
        time.total.to_h.each do |key, value|
          output "#{config[:scheme]}.utilizations_by_time.#{key}", value, Time.parse(time.time_period.end).to_i
        end
      end
    rescue StandardError => e
      critical "Error: exception: #{e}"
    end
    ok
  end
end
