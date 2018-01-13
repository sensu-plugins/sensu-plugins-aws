#! /usr/bin/env ruby
#
# check-route
#
# DESCRIPTION:
#   This plugin checks a route to an instance / eni on a route table
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
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright (c) 2014, Leon Gibat, brendan.gibat@gmail.com
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'aws-sdk'
require 'sensu-plugins-aws'

class CheckRoute < Sensu::Plugin::Check::CLI
  include Common
  include Filter

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default: 'us-east-1'

  option :filter,
         short: '-f FILTER',
         long: '--filter FILTER',
         description: 'String representation of the filter to apply',
         default: '{}'

  option :network_interface_id,
         description: 'Network interface id of route',
         short: '-n NETWORK_INTERFACE_ID',
         long: '--network-interface-id NETWORK_INTERFACE_ID',
         default: ''

  option :instance_id,
         description: 'Instance Id attachment of route',
         short: '-i INSTANCE_ID',
         long: '--instance-id INSTANCE_ID',
         default: ''

  option :destination_cidr_block,
         description: 'Destination CIDR block of route',
         short: '-d DESTINATION_CIDR',
         long: '--destination-cidr DESTINATION_CIDR',
         default: ''

  option :gateway_id,
         description: 'Gateway Id of route',
         short: '-g GATEWAY_ID',
         long: '--gateway-id GATEWAY_ID',
         default: ''

  option :state,
         description: 'The route state. Can be either "active" or "blackhole"',
         short: '-s STATE',
         long: '--state STATE',
         default: 'active'

  option :vpc_peering_id,
         description: 'VPC peering connection id',
         short: '-v VPC_PEERING_ID',
         long: '--vpc-peering-id VPC_PEERING_ID',
         default: ''

  def run
    begin
      aws_config
      client = Aws::EC2::Client.new

      filter = Filter.parse(config[:filter])

      options = { filters: filter }

      data = client.describe_route_tables(options)

      data[:route_tables].each do |rt|
        rt[:routes].each do |route|
          checks = true
          if config[:state] != route[:state]
            checks = false
          elsif !config[:vpc_peering_id].empty? && config[:vpc_peering_id] != route[:vpc_peering_connection_id]
            checks = false
          elsif !config[:gateway_id].empty? && config[:gateway_id] != route[:gateway_id]
            checks = false
          elsif !config[:destination_cidr_block].empty? && config[:destination_cidr_block] != route[:destination_cidr_block]
            checks = false
          elsif !config[:instance_id].empty? && config[:instance_id] != route[:instance_id]
            checks = false
          elsif !config[:network_interface_id].empty? && config[:network_interface_id] != route[:network_interface_id]
            checks = false
          end
          if checks
            ok
          end
        end
      end
    rescue StandardError => e
      critical "Error: exception: #{e}"
    end
    critical
  end
end
