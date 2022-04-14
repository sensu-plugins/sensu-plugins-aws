#!/usr/bin/env ruby
#
# check-target-group-instance-count
#
# DESCRIPTION:
#   This plugin checks the count of instances of Application Load Balancer target groups
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
#   Check the number of instances for a target group in a region
#   check-target-group-instance-count.rb -r region -t target-group -w warn-count -c crit-count
#
# LICENSE:
#   Copyright 2022 Etienne Duclos <etienne@tracktik.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.

require 'aws-sdk'
require 'sensu-plugin/check/cli'
require 'sensu-plugins-aws'

class CheckTargetGroupInstanceCount < Sensu::Plugin::Check::CLI
  include Common

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default: 'us-east-1'

  option :target_group,
         short: '-t',
         long: '--target-group TARGET_GROUP',
         description: 'The ALB target group to check'

  option :warn_count,
         short: '-W WARN_COUNT',
         long: '--warn WARN_COUNT',
         description: 'Warn when the number of instances is equal or below this number',
         default: 2,
         proc: proc(&:to_i)

  option :crit_count,
         short: '-C CRIT_COUNT',
         long: '--crit CRIT_COUNT',
         description: 'Critical when the number of instances is equal or below this number',
         default: 1,
         proc: proc(&:to_i)

  def alb
    @alb ||= Aws::ElasticLoadBalancingV2::Client.new
  end

  def run
    target_group = alb.describe_target_groups(names: [config[:target_group]]).target_groups[0]
    health = alb.describe_target_health(target_group_arn: target_group.target_group_arn)
    instances_count = health.target_health_descriptions.length

    message = "Number of instances in target group: #{instances_count}"

    if instances_count <= config[:crit_count]
      critical message
    elsif instances_count <= config[:warn_count]
      warning message
    else
      ok message
    end
  end
end
