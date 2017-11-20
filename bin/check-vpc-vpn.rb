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

  option :warn_count,
         short: '-W WARN_COUNT',
         long: '--warn_count WARN_COUNT',
         description: 'Warn when the count of down tunnels is at or above this number',
         default: 1,
         proc: proc(&:to_i)

  option :crit_count,
         short: '-C CRIT_COUNT',
         long: '--crit_count CRIT_COUNT',
         description: 'Critical when the count of down tunnels is at or above this number',
         default: 2,
         proc: proc(&:to_i)

  def fetch_connection_data
    begin
      ec2 = Aws::EC2::Client.new
      vpn_info = ec2.describe_vpn_connections(vpn_connection_ids: [config[:vpn_id]]).vpn_connections
      down_connections = vpn_info.first.vgw_telemetry.reject { |x| x.status == 'UP' }
      results = { down_count: down_connections.count }
      results[:down_connection_status] = down_connections.map { |x| "#{x.outside_ip_address} => #{x.status_message.empty? ? 'none' : x.status_message}" }
      results[:connection_name] = vpn_info[0].tags.find { |x| x.key == 'Name' }.value
    rescue Aws::EC2::Errors::ServiceError
      warning "The vpnConnection ID '#{config[:vpn_id]}' does not exist"
    rescue StandardError => e
      warning e.backtrace.join(' ')
    end
    results
  end

  def run
    data = fetch_connection_data
    msg = data[:down_connection_status].join(' | ')
    name = data[:connection_name]
    case data[:down_count]
    when 2 then message = "'#{name}' shows both tunnels as DOWN - [ #{msg} ]"
    when 1 then message = "'#{name}' shows 1 of 2 tunnels as DOWN - [ #{msg} ]"
    end

    if data[:down_count] >= config[:crit_count]
      critical message
    elsif data[:down_count] >= config[:warn_count]
      warning message
    else
      up_count = 2 - data[:down_count]
      ok "'#{name}' shows #{up_count} of 2 tunnels as UP"
    end
  end
end
