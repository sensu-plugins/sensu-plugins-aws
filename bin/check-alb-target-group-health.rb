#!/usr/bin/env ruby
#
# check-alb-target-group-health
#
# DESCRIPTION:
#   This plugin checks the health of Application Load Balancer target groups
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
#   Check all target groups in a region
#   check-alb-target-group-health.rb -r region
#
#   Check a single target group in a region
#   check-alb-target-group-health.rb -r region -t target-group
#
#   Check multiple target groups in a region
#   check-alb-target-group-health.rb -r region -t target-group-a,target-group-b
#
# LICENSE:
#   Copyright 2017 Eric Heydrick <eheydrick@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.

require 'aws-sdk'
require 'sensu-plugin/check/cli'
require 'sensu-plugins-aws'

class CheckALBTargetGroupHealth < Sensu::Plugin::Check::CLI
  include Common

  option :target_group,
         short: '-t',
         long: '--target-group TARGET_GROUP',
         description: 'The ALB target group(s) to check. Separate multiple target groups with commas'

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default: 'us-east-1'

  option :crit,
         short: '-c',
         long: '--crit',
         description: 'Critical instead of warn when unhealthy targets are found',
         boolean: true,
         default: false

  def alb
    @alb ||= Aws::ElasticLoadBalancingV2::Client.new
  end

  def unhealthy_target_groups
    unhealthy_groups = {}

    target_groups_to_check = config[:target_group].split(',') if config[:target_group]
    target_groups = alb.describe_target_groups(names: target_groups_to_check).target_groups

    target_groups.each do |target_group|
      health = alb.describe_target_health(target_group_arn: target_group.target_group_arn)
      unhealthy_targets = health.target_health_descriptions.select { |t| t.target_health.state == 'unhealthy' }.map { |t| t.target.id }
      healthy_targets = health.target_health_descriptions.select { |t| t.target_health.state == 'healthy' }.map { |t| t.target.id }
      if !unhealthy_targets.empty? || healthy_targets.empty?
        unhealthy_groups[target_group.target_group_name] = {
          unhealthy_targets: unhealthy_targets,
          healthy_targets: healthy_targets,
          total_targets: health.target_health_descriptions.size
        }
      end
    end
    unhealthy_groups
  end

  def run
    unhealthy_groups = unhealthy_target_groups

    if !unhealthy_groups.empty?
      message = 'Unhealthy ALB target groups: '
      message += unhealthy_groups.map { |target_group, value| "#{target_group} - #{value[:unhealthy_targets].size}/#{value[:total_targets]} unhealthy targets: {#{value[:unhealthy_targets].join(', ')}}" }.join(', ')
      message += ' : Healthy ALB target groups: '
      message += unhealthy_groups.map { |target_group, value| "#{target_group} - #{value[:healthy_targets].size}/#{value[:total_targets]} healthy targets: {#{value[:healthy_targets].join(', ')}}" }.join(', ')
      if config[:crit]
        critical message
      else
        warning message
      end
    else
      ok 'All ALB target groups are healthy'
    end
  end
end
