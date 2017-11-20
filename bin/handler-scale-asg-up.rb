#! /usr/bin/env ruby
#
#  handler-scale-up-asg
#
# DESCRIPTION:
# => Increases the desired capacity of an AutoscalingGroup
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: aws-sdk
#
# USAGE:
# -j JSONCONFIG - The name of a json config file to be used
#
# NOTES:
# Json config by default should be named asg_scaler.json and should have 2 levels.
# First level contains: "asg_scaler"
# Second level contains: "autoscaling_group" and "cooldown_period"
# example of a valid asg_scaler.json:
# {
#  "asg_scaler":
#  {
#    "autoscaling_group":"SomeGroupName",
#    "cooldown_period":"36"
#  }
# }
#
# LICENSE:
#   Brian Sizemore <bpsizemore@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'aws-sdk'
require 'json'
require 'sensu-handler'

class AsgScaler < Sensu::Handler
  option :json_config,
         description: 'Name of the json config file',
         short: '-j JSONCONFIG',
         long: '--json JSONCONFIG',
         default: 'asg_scaler'

  def autoscaling_group
    get_setting('autoscaling_group')
  end

  def cooldown_period
    get_setting('cooldown_period')
  end

  def json_config
    cli ||= AsgScaler.new
    cli.config[:json_config]
  end

  def get_setting(name)
    config_file ||= File.read("#{json_config}.json")
    config ||= JSON.parse(config_file)
    config['asg_scaler'][name]
  end

  def handle
    @asg = autoscaling_group
    @autoscaling = Aws::AutoScaling::Client.new
    if !out_of_cooldown
      puts "An autoscaling event took place within the past #{cooldown_period} minutes. No action will be taken."
    else
      puts "No event has taken place within the past #{cooldown_period} minutes. Proceeding..."
      begin_scaling
    end
  end

  def asg_max_instances
    resp = @autoscaling.describe_auto_scaling_groups(auto_scaling_group_names: [@asg],
                                                     max_records: 1)
    resp[0][0][4]
  end

  def filter_silenced
    # The inhereted filter_silenced method is not working, currently investigating.
    #   Handler works properly with this spoofed method.
  end

  def out_of_cooldown
    resp = @autoscaling.describe_scaling_activities(auto_scaling_group_name: @asg,
                                                    max_records: 1)
    resp = resp[0][0][4].to_s
    resp = resp.sub(' ', 'T')
    resp = resp.sub(' UTC', '+00:00')

    # Time of last autoscaling event
    aws = DateTime.iso8601(resp) # rubocop: disable Style/DateTime

    # Current System Time
    now = DateTime.now.new_offset(0) # rubocop: disable Style/DateTime
    diff = (now - aws).to_f	# This produces time since last event in days
    diff = diff * 24 * 60	# This produces the time since last event in minutes
    diff > cooldown_period.to_f
  end

  def current_size
    resp = @autoscaling.describe_auto_scaling_groups(auto_scaling_group_names: [@asg],
                                                     max_records: 1)
    resp[0][0][5]
  end

  def scale_up
    size = current_size.to_i
    new_size = size + 1
    puts 'scaling down...'
    @autoscaling.set_desired_capacity(auto_scaling_group_name: @asg,
                                      desired_capacity: new_size)
  end

  def begin_scaling
    stack_size = current_size
    if stack_size < asg_max_instances
      scale_up
    else
      puts 'The cluster has the maximum amount of instances. No action will be taken.'
    end
  end
end
