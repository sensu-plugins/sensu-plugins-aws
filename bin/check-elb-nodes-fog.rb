#!/usr/bin/env ruby
#
# Checks the number of in service nodes in an AWS ELB
# ===
#
# DESCRIPTION:
#   This plugin checks an AWS Elastic Load Balancer to ensure a minimum number
#   or percentage of nodes are InService on the ELB
#
# PLATFORMS:
#   all
#
# DEPENDENCIES:
#   sensu-plugin >= 1.5 Ruby gem
#   aws-sdk Ruby gem
#
# Copyright (c) 2013, Justin Lambert <jlambert@letsevenup.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'net/http'
require 'uri'
require 'fog'

class CheckELBNodes < Sensu::Plugin::Check::CLI

  option :aws_access_key,
    :short => '-a AWS_ACCESS_KEY',
    :long => '--aws-access-key AWS_ACCESS_KEY',
    :description => "AWS Access Key. Either set ENV['AWS_ACCESS_KEY_ID'] or provide it as an option",
    :required => false

  option :aws_secret_access_key,
    :short => '-s AWS_SECRET_ACCESS_KEY',
    :long => '--aws-secret-access-key AWS_SECRET_ACCESS_KEY',
    :description => "AWS Secret Access Key. Either set ENV['AWS_SECRET_ACCESS_KEY'] or provide it as an option",
    :required => false

  option :aws_region,
    :short => '-r AWS_REGION',
    :long => '--aws-region REGION',
    :description => "AWS Region (such as eu-west-1).",
    :default => 'us-east-1'

  option :load_balancer,
    :short => '-n ELB_NAME',
    :long => '--name ELB_NAME',
    :description => 'The name of the ELB',
    :required => true

  option :warn_under,
    :short  => '-w WARN_NUM',
    :long  => '--warn WARN_NUM',
    :description => 'Minimum number of nodes InService on the ELB to be considered a warning',
    :default => -1,
    :proc => proc { |a| a.to_i }

  option :crit_under,
    :short  => '-c CRIT_NUM',
    :long  => '--crit CRIT_NUM',
    :description => 'Minimum number of nodes InService on the ELB to be considered critical',
    :default => -1,
    :proc => proc { |a| a.to_i }

  option :warn_percent,
    :short => '-W WARN_PERCENT',
    :long => '--warn_perc WARN_PERCENT',
    :description => 'Warn when the percentage of InService nodes is at or below this number',
    :default => -1,
    :proc => proc { |a| a.to_i }

  option :crit_percent,
    :short => '-C CRIT_PERCENT',
    :long => '--crit_perc CRIT_PERCENT',
    :description => 'Minimum percentage of nodes needed to be InService',
    :default => -1,
    :proc => proc { |a| a.to_i }

  def run

    if config[:aws_access_key].nil?
      elb = Fog::AWS::ELB.new(
        :use_iam_profile => true,
        :region => config[:aws_region]
      )
    else
      elb = Fog::AWS::ELB.new(
        :aws_access_key_id => config[:aws_access_key],
        :aws_secret_access_key => config[:aws_secret_access_key],
        :region => config[:aws_region]
      )
    end
    begin
      health = elb.describe_instance_health(config[:load_balancer])
    rescue Fog::AWS::ELB::NotFound
      unknown "A load balancer with the name '#{config[:load_balancer]}' was not found"
    end
  
    unhealthy_instances = {}
    healthy_instances = {}

    health.body['DescribeInstanceHealthResult']['InstanceStates'].each do |instance|
      unhealthy_instances[instance['InstanceId']] = instance['State'] unless instance['State'].eql?('InService')
      healthy_instances[instance['InstanceId']] = instance['State'] unless instance['State'].eql?('OutOfService')
    end 

    num_instances = healthy_instances.count.to_f + unhealthy_instances.count.to_f
    state = { 'OutOfService' => [], 'InService' => [], 'Unknown' => []}
    health.body['DescribeInstanceHealthResult']['InstanceStates'].each do |instance|
      state[instance['State']] << instance['InstanceId']
    end

    message = "InService: #{state['InService'].count}"
    if state['InService'].count > 0
      message << " (#{state['InService'].join(', ')})"
    end
    message << "; OutOfService: #{state['OutOfService'].count}"
    if state['OutOfService'].count > 0
      message << " (#{state['OutOfService'].join(', ')})"
    end
    if state['Unknown'].count > 0
      message << " (#{state['Unknown'].join(', ')})"
    end

    if state['Unknown'].count == num_instances
      unknown "All nodes in unknown state"
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
