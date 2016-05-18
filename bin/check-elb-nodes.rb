#! /usr/bin/env ruby
#
# check-elb-nodes
#
# DESCRIPTION:
#   This plugin checks an AWS Elastic Load Balancer to ensure a minimum number
#   or percentage of nodes are InService on the ELB
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: aws-sdk-v1
#   gem: sensu-plugin
#
# USAGE:
#   Warning if the load balancer has 3 or fewer healthy nodes and critical if 2 or fewer
#   check-elb-nodes --warn 3 --crit 2
#
#   Warning if the load balancer has 50% or less healthy nodes and critical if 25% or less
#   check-elb-nodes --warn_perc 50 --crit_perc 25
#
# NOTES:
#
# LICENSE:
#   Copyright (c) 2013, Justin Lambert <jlambert@letsevenup.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'aws-sdk-v1'

class CheckELBNodes < Sensu::Plugin::Check::CLI
  option :aws_access_key,
         short: '-a AWS_ACCESS_KEY',
         long: '--aws-access-key AWS_ACCESS_KEY',
         description: "AWS Access Key. Either set ENV['AWS_ACCESS_KEY'] or provide it as an option",
         default: ENV['AWS_ACCESS_KEY']

  option :aws_secret_access_key,
         short: '-k AWS_SECRET_KEY',
         long: '--aws-secret-access-key AWS_SECRET_KEY',
         description: "AWS Secret Access Key. Either set ENV['AWS_SECRET_KEY'] or provide it as an option",
         default: ENV['AWS_SECRET_KEY']

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default: 'us-east-1'

  option :load_balancer,
         short: '-n ELB_NAME',
         long: '--name ELB_NAME',
         description: 'The name of the ELB',
         required: true

  option :warn_under,
         short: '-w WARN_NUM',
         long: '--warn WARN_NUM',
         description: 'Minimum number of nodes InService on the ELB to be considered a warning',
         default: -1,
         proc: proc(&:to_i)

  option :crit_under,
         short: '-c CRIT_NUM',
         long: '--crit CRIT_NUM',
         description: 'Minimum number of nodes InService on the ELB to be considered critical',
         default: -1,
         proc: proc(&:to_i)

  option :warn_percent,
         short: '-W WARN_PERCENT',
         long: '--warn_perc WARN_PERCENT',
         description: 'Warn when the percentage of InService nodes is at or below this number',
         default: -1,
         proc: proc(&:to_i)

  option :crit_percent,
         short: '-C CRIT_PERCENT',
         long: '--crit_perc CRIT_PERCENT',
         description: 'Minimum percentage of nodes needed to be InService',
         default: -1,
         proc: proc(&:to_i)

  def aws_config
    { access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key],
      region: config[:aws_region] }
  end

  def run
    AWS.start_memoizing
    elb = AWS::ELB.new aws_config

    begin
      instances = elb.load_balancers[config[:load_balancer]].instances.health
    rescue AWS::ELB::Errors::LoadBalancerNotFound
      unknown "A load balancer with the name '#{config[:load_balancer]}' was not found"
    end

    num_instances = instances.count.to_f
    state = { 'OutOfService' => [], 'InService' => [], 'Unknown' => [] }
    instances.each do |instance|
      # Force a requery of state
      AWS.stop_memoizing if instance[:state] == 'Unknown'
      state[instance[:state]] << instance[:instance].id
    end
    AWS.stop_memoizing

    message = "InService: #{state['InService'].count}"
    if state['InService'].count > 0
      message << " (#{state['InService'].join(', ')})"
    end
    message << "; OutOfService: #{state['OutOfService'].count}"
    if state['OutOfService'].count > 0
      message << " (#{state['OutOfService'].join(', ')})"
    end
    message << "; Unknown: #{state['Unknown'].count}"
    if state['Unknown'].count > 0
      message << " (#{state['Unknown'].join(', ')})"
    end

    if state['Unknown'].count == num_instances
      unknown 'All nodes in unknown state'
    elsif state['InService'].count == 0
      critical message
    elsif config[:crit_under] > 0 && config[:crit_under] >= state['InService'].count
      critical message
    elsif config[:crit_percent] > 0 && config[:crit_percent] >= (state['InService'].count / num_instances) * 100
      critical message
    elsif config[:warn_under] > 0 && config[:warn_under] >= state['InService'].count
      warning message
    elsif config[:warn_percent] > 0 && config[:warn_percent] >= (state['InService'].count / num_instances) * 100
      warning message
    else
      ok message
    end
  end
end
