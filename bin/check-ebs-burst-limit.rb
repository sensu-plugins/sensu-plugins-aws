#! /usr/bin/env ruby
#
# check-ebs-burst-limit
#
# DESCRIPTION:
#   Check EC2 Attached Volumes for volumes with low burst balance
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
#   ./check-ebs-burst-limit.rb -r ${you_region}
#   ./check-ebs-burst-limit.rb -r ${you_region} -c 50
#   ./check-ebs-burst-limit.rb -r ${you_region} -w 50 -c 10
#
# LICENSE:
#   Barry Martin <nyxcharon@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'sensu-plugins-aws/cloudwatch-common'
require 'sensu-plugins-aws'
require 'aws-sdk'

class CheckEbsSnapshots < Sensu::Plugin::Check::CLI
  include Common
  include CloudwatchCommon

  option :aws_region,
         short:       '-r R',
         long:        '--region REGION',
         description: 'AWS region',
         default: 'us-east-1'

  option :critical,
         description: 'Trigger a critical when ebs purst limit is under VALUE',
         short: '-c VALUE',
         long: '--critical VALUE',
         proc: proc(&:to_f),
         required: true

  option :warning,
         description: 'Trigger a warning when ebs purst limit is under VALUE',
         short: '-w VALUE',
         long: '--warning VALUE',
         proc: proc(&:to_f)

  def run
    errors = []
    ec2 = Aws::EC2::Client.new
    volumes = ec2.describe_volumes(
      filters: [
        {
          name: 'attachment.status',
          values: ['attached']
        }
      ]
    )
    config[:metric_name] = 'BurstBalance'
    config[:namespace] = 'AWS/EBS'
    config[:statistics] = 'Average'
    config[:period] = 60
    crit = false
    should_warn = false

    volumes[:volumes].each do |volume|
      config[:dimensions] = []
      config[:dimensions] << { name: 'VolumeId', value: volume[:volume_id] }
      resp = client.get_metric_statistics(metrics_request(config))
      unless resp.datapoints.first.nil?
        if resp.datapoints.first[:average] < config[:critical]
          errors << "#{volume[:volume_id]} #{resp.datapoints.first[:average]}"
          crit = true
        elsif resp.datapoints.first[:average] < config[:warning]
          errors << "#{volume[:volume_id]} #{resp.datapoints.first[:average]}"
          should_warn = true
        end
      end
    end

    if crit
      critical "Volume(s) have exceeded critical threshold: #{errors}"
    elsif should_warn
      warning "Volume(s) have exceeded warning threshold: #{errors}"
    else
      ok 'No volume(s) exceed thresholds'
    end
  end
end
