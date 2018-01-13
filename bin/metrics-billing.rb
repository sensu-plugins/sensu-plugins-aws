#! /usr/bin/env ruby
#
# s3-billing
#
# DESCRIPTION:
#   Gets Billing metrics from CloudWatch and puts them in Graphite for longer term storage
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
#   metrics-billing.rb
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

class BillingMetrics < Sensu::Plugin::Metric::CLI::Graphite
  include Common

  option :services_name,
         short: '-S SERVICES_NAME',
         long: '--services-name SERVICES_NAME',
         description: 'The name of the AWS service (http://docs.aws.amazon.com/AmazonCloudWatch/latest/DeveloperGuide/billing-metricscollected.html)',
         default: 'AmazonEC2,AWSDataTransfer'

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: 'sensu.aws.billing'

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default: 'us-east-1'

  def run
    begin
      cw = Aws::CloudWatch::Client.new(aws_config)
      now = Time.now
      r = cw.get_metric_statistics(
        namespace: 'AWS/Billing',
        metric_name: 'EstimatedCharges',
        dimensions: [
          {
            name: 'Currency',
            value: 'USD'
          }
        ],
        start_time: (now.utc - 6 * 60 * 60).iso8601,
        end_time: now.utc.iso8601,
        period: 6 * 60 * 60,
        statistics: ['Maximum'],
        unit: 'None'
      )
      output "#{config[:scheme]}.total.estimated_charges", r[:datapoints][0].maximum, r[:datapoints][0][:timestamp].to_i unless r[:datapoints][0].nil?

      config[:services_name].split(',').each do |service_name|
        r = cw.get_metric_statistics(
          namespace: 'AWS/Billing',
          metric_name: 'EstimatedCharges',
          dimensions: [
            { name: 'Currency', value: 'USD' },
            { name: 'ServiceName', value: service_name }
          ],
          start_time: (now.utc - 6 * 60 * 60).iso8601,
          end_time: now.utc.iso8601,
          period: 6 * 60 * 60,
          statistics: ['Maximum'],
          unit: 'None'
        )
        output "#{config[:scheme]}.total.#{service_name}", r[:datapoints][0].maximum, r[:datapoints][0][:timestamp].to_i unless r[:datapoints][0].nil?
      end
    rescue StandardError => e
      critical "Error: exception: #{e}"
    end
    ok
  end
end
