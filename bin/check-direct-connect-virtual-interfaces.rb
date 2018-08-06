#! /usr/bin/env ruby
#
# check-direct-connect-virtual-interfaces
#
# DESCRIPTION:
#   This plugin uses the AWS Direct Connect API to check the status
#   of virtual interfaces
#
#   CRIT: one or more interfaces status not 'available' (down)
#   WARN: no virtual interfaces detected
#   OK:   all interfaces checked available
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   Linux, Windows, Mac
#
# DEPENDENCIES:
#   gem: aws-sdk
#   gem: sensu-plugin
#
# USAGE:
#  ./check-direct-connect.rb -r {us-east-1|eu-west-1} [-c all]
#
# NOTES:
#
# LICENSE:
#   Guillaume Delacour <guillaume.delacour@fr.clara.net>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.

require 'sensu-plugin/check/cli'
require 'sensu-plugins-aws'
require 'aws-sdk'

class CheckDcVirtualInterfacesHealth < Sensu::Plugin::Check::CLI
  include Common

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region AWS_REGION',
         description: 'The AWS region in which to check rules. Currently only available in us-east-1.',
         default: 'us-east-1'

  option :connection_id,
         short: '-c CONNECTION_ID',
         long: '--connection-id CONNECTION_ID',
         description: 'The connection id to check. Default is to check all connection ids',
         default: 'all'

  def dc_client
    @dc_client ||= Aws::DirectConnect::Client.new
  end

  def virtual_interfaces_details(connection_id = 'all')
    if connection_id == 'all'
      dc_client.describe_virtual_interfaces
    else
      dc_client.describe_virtual_interfaces(connection_id: connection_id)
    end
  end

  def run
    virtual_interfaces_healths = virtual_interfaces_details(config[:connection_id])
    if virtual_interfaces_healths[0].length.zero?
      warning('No virtual interfaces to check')
    end

    unhealthy = []

    virtual_interfaces_healths[0].each do |virtual_interface|
      unhealthy.push(virtual_interface.virtual_interface_name) if virtual_interface.virtual_interface_state != 'available'
    end

    if !unhealthy.length.zero?
      critical("Not 'available' virtual interfaces: #{unhealthy.join ', '}")
    else
      ok(config[:connection_id].to_s)
    end
  rescue StandardError => e
    unknown "An error occurred processing AWS DirectConnect API: #{e.message}"
  end
end
