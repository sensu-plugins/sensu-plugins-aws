#! /usr/bin/env ruby
#
#   check-vpc-vpn.rb
#
# DESCRIPTION:
#   This plugin checks VPC VPN connections to ensure they are up
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   all
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: aws-sdk
#   gem: sensu-plugins-aws
#
# USAGE:
#  ./check-vpc-vpn.rb --aws-region us-east-1 --vpn-connection-id vpn-abc1234
#
# NOTES:
#   Supports inline credentials or IAM roles
#
# LICENSE:
#   John Dyer johntdyer@gmail.com
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#   Updated by Peter Hoppe <peter.hoppe.extern@bertelsmann.de> to aws-sdk-v2
#

require 'sensu-plugins-aws'
require 'sensu-plugin/check/cli'
require 'aws-sdk'

class CheckAwsVpcVpnConnections < Sensu::Plugin::Check::CLI
  include Common
  option :vpn_id,
    short: '-v VPN_ID',
    long: '--vpn-connection-id VPN_ID',
    required: true,
    description: 'VPN connection ID'

  option :aws_region,
     short: '-r AWS_REGION',
     long: '--aws-region REGION',
     description: 'AWS Region (defaults to us-east-1).',
     default: ENV['AWS_REGION']


  def fetch_connection_data
    begin
      ec2 = Aws::EC2::Client.new
      vpn_info = ec2.describe_vpn_connections(vpn_connection_ids: [config[:vpn_id]]).vpn_connections
      down_connections = vpn_info.first.vgw_telemetry.select { |x| x.status != 'UP' }
      results = { down_count: down_connections.count }
      results[:down_connection_status] = down_connections.map { |x| "#{x.outside_ip_address} => #{x.status_message.empty? ? 'none' : x.status_message}" }
      results[:connection_name] = vpn_info[0].tags.find { |x| x.key == 'Name' }.value
    rescue Aws::EC2::Errors::ServiceError
      warning "The vpnConnection ID '#{config[:vpn_id]}' does not exist"
    rescue => e
      warning e.backtrace.join(' ')
    end
    results
  end

  def run
    data = fetch_connection_data
    msg = data[:down_connection_status].join(' | ')
    name = data[:connection_name]
    case data[:down_count]
    when 2 then critical "'#{name}' shows both tunnels as DOWN - [ #{msg} ]"
    when 1 then warning "'#{name}' shows 1 of 2 tunnels as DOWN - [ #{msg} ]"
    when 0 then ok "'#{name}' shows 2 of 2 tunnels as UP"
    else
      # Not sure this could ever happen
      unknown "Unknown connection count - #{data[:down_count]}"
    end
  end
end
