#! /usr/bin/env ruby
#
# check-ses-statistics
#
# DESCRIPTION:
#   Alerts on threshold values for SES statistics
#
# OUTPUT:
#   plain-text
#
# DEPENDENCIES:
#   gem: aws-sdk
#   gem: sensu-plugin
#
# USAGE:
#   check-ses-statistics.rb -r us-west-2 -b 1 -B 2 -c 5 -C 10 -j 10 -J 20
#
#   This will alert on bounces, complaints, rejects or delivery attempts
#   if they equal or exceed (>=) threshold values,
#
#   It will alert on delivery attempts if they fall below (<) threshold values.
#
# NOTES:
#
# LICENSE:
#   Brandon Smith <freedom@reardencode.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.

require 'sensu-plugins-aws'
require 'sensu-plugin/check/cli'
require 'aws-sdk'

class CheckSesStatistics < Sensu::Plugin::Check::CLI
  include Common

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default: 'us-east-1'

  option :low_delivery_warn,
         short: '-l COUNT',
         long: '--low_delivery_warn',
         description: 'Number of delivery attempts to warn below.',
         default: 0,
         proc: proc(&:to_i)

  option :low_delivery_crit,
         short: '-L COUNT',
         long: '--low_delivery_crit',
         description: 'Number of delivery attempts to alert below.',
         default: 0,
         proc: proc(&:to_i)

  option :delivery_warn,
         short: '-d COUNT',
         long: '--delivery_warn',
         description: 'Number of delivery attempts to warn above.',
         default: 0,
         proc: proc(&:to_i)

  option :delivery_crit,
         short: '-D COUNT',
         long: '--delivery_crit',
         description: 'Number of delivery attempts to alert above.',
         default: 0,
         proc: proc(&:to_i)

  option :complaint_warn,
         short: '-c COUNT',
         long: '--complaint_warn',
         description: 'Number of complaints to warn above.',
         default: 0,
         proc: proc(&:to_i)

  option :complaint_crit,
         short: '-C COUNT',
         long: '--complaint_crit',
         description: 'Number of complaints to alert above.',
         default: 0,
         proc: proc(&:to_i)

  option :reject_warn,
         short: '-j COUNT',
         long: '--reject_warn',
         description: 'Number of rejects to warn above.',
         default: 0,
         proc: proc(&:to_i)

  option :reject_crit,
         short: '-J COUNT',
         long: '--reject_crit',
         description: 'Number of rejects to alert above.',
         default: 0,
         proc: proc(&:to_i)

  option :bounce_warn,
         short: '-b COUNT',
         long: '--bounce_warn',
         description: 'Number of bounces to warn above.',
         default: 0,
         proc: proc(&:to_i)

  option :bounce_crit,
         short: '-B COUNT',
         long: '--bounce_crit',
         description: 'Number of bounces to alert above.',
         default: 0,
         proc: proc(&:to_i)

  def run
    ses = Aws::SES::Client.new(aws_config)
    begin
      response = ses.get_send_statistics

      unknown 'Empty response from AWS SES API' if response.empty? # Can this happen?
      unknown 'No data points from AWS SES API' if response.send_data_points.empty?

      data_point = response.send_data_points.sort_by(&:timestamp).last
      bounces = data_point.bounces
      rejects = data_point.rejects
      complaints = data_point.complaints
      delivery_attempts = data_point.delivery_attempts

      message = "SES stats for #{data_point.timestamp}: "\
        "#{delivery_attempts} delivery attempts, #{bounces} bounces, #{rejects} rejects, #{complaints} complaints"

      if config[:complaint_crit] > 0 && config[:complaint_crit] <= complaints || \
         config[:reject_crit] > 0 && config[:reject_crit] <= rejects || \
         config[:bounce_crit] > 0 && config[:bounce_crit] <= bounces || \
         config[:low_delivery_crit] > 0 && config[:low_delivery_crit] > bounces || \
         config[:delivery_crit] > 0 && config[:delivery_crit] <= bounces

        critical message
      elsif config[:complaint_warn] > 0 && config[:complaint_warn] <= complaints || \
            config[:reject_warn] > 0 && config[:reject_warn] <= rejects || \
            config[:bounce_warn] > 0 && config[:bounce_warn] <= bounces || \
            config[:low_delivery_warn] > 0 && config[:low_delivery_warn] > bounces || \
            config[:delivery_warn] > 0 && config[:delivery_warn] <= bounces

        warning message
      else
        ok message
      end
    end
  end
end
