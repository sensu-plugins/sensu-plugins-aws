#! /usr/bin/env ruby
#
# check-reserved-instances
#
# DESCRIPTION:
#   This plugin checks if reserved instances expire soon.
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
#   ./check-reserved-instances.rb --aws-region eu-west-1 --use-iam
#
# NOTES:
#
# LICENSE:
#   Copyright (c) 2015, Olivier Bazoud, olivier.bazoud@gmail.com
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'sensu-plugins-aws'
require 'aws-sdk'

class CheckReservedInstances < Sensu::Plugin::Check::CLI
  include Common

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default: 'us-east-1'

  option :warning,
         description: 'Warn if expire date is lower age in seconds',
         short: '-w SECONDS',
         long: '--warning SECONDS',
         default: 60 * 60 * 24 * 5,
         proc: proc(&:to_i)

  option :critical,
         description: 'Critical if expire date is lower age in seconds',
         short: '-c SECONDS',
         long: '--critical SECONDS',
         default: 60 * 60 * 24 * 30 * 2,
         proc: proc(&:to_i)

  def run
    reserved_instances_critical = []
    reserved_instances_warning = []

    ec2 = Aws::EC2::Client.new
    reserved_instances = ec2.describe_reserved_instances(filters: [{ name: 'state', values: ['active'] }]).reserved_instances

    reserved_instances.each do |reserved_instance|
      age = reserved_instance.end.to_i - Time.now.to_i
      if age < config[:critical]
        reserved_instances_critical << reserved_instance.reserved_instances_id
      elsif age < config[:warning]
        reserved_instances_warning << reserved_instance.reserved_instances_id
      end
    end

    if !reserved_instances_critical.empty?
      critical "Reserved instances will expire soon - #{reserved_instances_critical}"
    elsif !reserved_instances_warning.empty?
      warning "Reserved instances will expire soon - #{reserved_instances_warning}"
    end

    ok "#{reserved_instances.size} reserved instances"
  end
end
