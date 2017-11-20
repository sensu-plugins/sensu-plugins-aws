#! /usr/bin/env ruby
#
# check-ec2-network
#
# DESCRIPTION:
#   Check EC2 Network Metrics by CloudWatch API.
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: aws-sdk
#   gem: sensu-plugin
#
# USAGE:
#   ./check-ec2-network.rb -r ${you_region} -i ${your_instance_id} --warning-over 1000000 --critical-over 1500000
#   ./check-ec2-network.rb -r ${you_region} -i ${your_instance_id} -d NetworkIn --warning-over 1000000 --critical-over 1500000
#   ./check-ec2-network.rb -r ${you_region} -i ${your_instance_id} -d NetworkOut --warning-over 1000000 --critical-over 1500000
#
# NOTES:
#
# LICENSE:
#   Yohei Kawahara <inokara@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'aws-sdk'

class CheckEc2Network < Sensu::Plugin::Check::CLI
  option :aws_access_key,
         short:       '-a AWS_ACCESS_KEY',
         long:        '--aws-access-key AWS_ACCESS_KEY',
         description: "AWS Access Key. Either set ENV['AWS_ACCESS_KEY'] or provide it as an option",
         default:     ENV['AWS_ACCESS_KEY']

  option :aws_secret_access_key,
         short:       '-k AWS_SECRET_KEY',
         long:        '--aws-secret-access-key AWS_SECRET_KEY',
         description: "AWS Secret Access Key. Either set ENV['AWS_SECRET_KEY'] or provide it as an option",
         default:     ENV['AWS_SECRET_KEY']

  option :aws_region,
         short:       '-r AWS_REGION',
         long:        '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default:     'us-east-1'

  option :instance_id,
         short:       '-i instance-id',
         long:        '--instance-id instance-ids',
         description: 'EC2 Instance ID to check.'

  option :end_time,
         short:       '-t T',
         long:        '--end-time TIME',
         default:     Time.now,
         description: 'CloudWatch metric statistics end time'

  option :period,
         short:       '-p N',
         long:        '--period SECONDS',
         default:     60,
         description: 'CloudWatch metric statistics period'

  option :direction,
         short:       '-d NetworkIn or NetworkOut',
         long:        '--direction NetworkIn or NetworkOut',
         default:     'NetworkIn',
         description: 'Select NetworkIn or NetworkOut'

  %w[warning critical].each do |severity|
    option :"#{severity}_over",
           long:        "--#{severity}-over COUNT",
           description: "Trigger a #{severity} if network traffice is over specified Bytes"
  end

  def aws_config
    { access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key],
      region: config[:aws_region] }
  end

  def ec2
    @ec2 ||= Aws::EC2::Client.new aws_config
  end

  def cloud_watch
    @cloud_watch ||= Aws::CloudWatch::Client.new aws_config
  end

  def network_metric(instance)
    cloud_watch.get_metric_statistics(
      namespace: 'AWS/EC2',
      metric_name: config[:direction].to_s,
      dimensions: [
        {
          name: 'InstanceId',
          value: instance
        }
      ],
      start_time: config[:end_time] - 300,
      end_time: config[:end_time],
      statistics: ['Average'],
      period: config[:period],
      unit: 'Bytes'
    )
  end

  def latest_value(value)
    value.datapoints[0][:average].to_f unless value.datapoints[0].nil?
  end

  def check_metric(instance)
    metric = network_metric instance
    latest_value metric unless metric.nil?
  end

  def run
    metric_value = check_metric config[:instance_id]
    if !metric_value.nil? && metric_value > config[:critical_over].to_f
      critical "#{config[:direction]} at #{metric_value} Bytes"
    elsif !metric_value.nil? && metric_value > config[:warning_over].to_f
      warning "#{config[:direction]} at #{metric_value} Bytes"
    else
      ok "#{config[:direction]} at #{metric_value} Bytes"
    end
  end
end
