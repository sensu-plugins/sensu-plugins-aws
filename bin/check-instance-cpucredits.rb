#!/usr/bin/env ruby
#
# check-instance-cpucredits
#
# DESCRIPTION:
#   This plugin checks the CPU credit balance of the instance it is ran on
#   and alerts if they are low.
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
#
#   Check the current instance's CPU credits and alert critical if below 10 and warning if below 50 and greater than 10:
#   check-instance-cpucredits.rb
#
#   Check the specified instance's CPU credits and alert critical if below 10 and warn below 50 (must specify region):
#   check-instance-cpucredits.rb -i i-0d2fe2a5f09338fef -r eu-west-1
#
#   Check instance CPU credits and warn if they are less than 100 and alert critical if below 10:
#   check-instance-cpucredits.rb -w 100 -c 10
#
#   Check instance CPU credits:
#   check-instance-cpucredits.rb -w 100 -c 10
#
# LICENSE:
#    MIT License
#
#    Copyright (c) 2017 Claranet
#
#    Permission is hereby granted, free of charge, to any person obtaining a copy
#    of this software and associated documentation files (the "Software"), to deal
#    in the Software without restriction, including without limitation the rights
#    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#    copies of the Software, and to permit persons to whom the Software is
#    furnished to do so, subject to the following conditions:
#
#    The above copyright notice and this permission notice shall be included in all
#    copies or substantial portions of the Software.
#
#    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#    SOFTWARE.
#

require 'net/http'
require 'aws-sdk'
require 'sensu-plugin/check/cli'

class CheckInstanceCpuCredits < Sensu::Plugin::Check::CLI
  VERSION = '0.0.1'.freeze

  option :warning,
         description: 'Issue a warning if the CPU credits for the instance fall below this value.',
         short:       '-w N',
         long:        '--warning VALUE',
         default:     50

  option :critical,
         description: 'Issue a critical if the CPU credits for the instance fall below this value.',
         short:       '-c N',
         long:        '--critical VALUE',
         default:     10

  option :instance_id,
         description: 'Instance ID to check the CPU credits for (optional)',
         short:       '-i ID',
         long:        '--instance-id ID'

  option :region,
         description: 'Instance ID to check the CPU credits for (optional)',
         short:       '-r REGION',
         long:        '--region REGION'

  option :metadata_endpoint,
         description: 'The AWS metadata server URL to use (optional)',
         short:       '-m URL',
         long:        '--metadata-url URL',
         default:     'http://169.254.169.254/latest/meta-data/'

  def my_instance_region
    # request the availability zone and strip the zone letter to be left with the region.
    region = Net::HTTP.get(URI.parse(config[:metadata_endpoint] + 'placement/availability-zone'))[0..-2]
    region
  end

  def my_instance_id
    instance_id = Net::HTTP.get(URI.parse(config[:metadata_endpoint] + 'instance-id'))
    instance_id
  end

  def current_cpu_credits
    cloud_watch = Aws::CloudWatch::Client.new(region: config[:region])

    cpu_credits = cloud_watch.get_metric_statistics(
      namespace: 'AWS/EC2',
      metric_name: 'CPUCreditBalance',
      dimensions: [
        {
          name: 'InstanceId',
          value: config[:instance_id]
        }
      ],
      start_time: Time.now - 600,
      end_time: Time.now,
      statistics: ['Average'],
      period: 60,
      unit: 'Count'
    )

    return cpu_credits.datapoints[0][:average].to_f unless cpu_credits.datapoints[0].nil?

    nil
  end

  def run
    config[:instance_id] = my_instance_id unless config[:instance_id]
    config[:region] = my_instance_region unless config[:region]

    cpu_credits = current_cpu_credits

    critical 'Unable to obtain CPU credit balance' unless cpu_credits

    message = "CPU credit balance is at #{cpu_credits}"

    if cpu_credits <= config[:critical].to_f
      critical message
    elsif cpu_credits <= config[:warning].to_f
      warning message
    else
      ok message
    end
  end
end
