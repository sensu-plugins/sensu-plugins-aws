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
#

require 'sensu-plugin/check/cli'
require 'aws-sdk'

class CheckAwsVpcVpnConnections < Sensu::Plugin::Check::CLI
  @aws_config = {}
  # rubocop:disable Style/AlignParameters
  option :access_key,
    short: '-a AWS_ACCESS_KEY',
    long: '--aws-access-key AWS_ACCESS_KEY',
    description: 'AWS Access Key',
    default: ENV['AWS_ACCESS_KEY_ID']

  option :secret_key,
    short: '-s AWS_SECRET_ACCESS_KEY',
    long: '--aws-secret-access-key AWS_SECRET_ACCESS_KEY',
    description: 'AWS Secret Access Key.',
    default: ENV['AWS_SECRET_ACCESS_KEY']

  option :use_iam_role,
    short: '-u',
    long: '--use-iam',
    description: 'Use IAM authentication'

  option :vpn_id,
    short: '-v VPN_ID',
    long: '--vpn-connection-id VPN_ID',
    required: true,
    description: 'VPN connection ID'

  option :aws_region,
    short: '-r AWS_REGION',
    long: '--aws-region REGION',
    description: 'AWS Region (such as eu-west-1).',
    default: 'us-east-1'

  def aws_config
    aws_connection_config = { region: config[:aws_region] }
    if config[:use_iam_role].nil?
      aws_connection_config.merge!(
        access_key_id: config[:access_key],
        secret_access_key: config[:secret_key]
      )
    end
    aws_connection_config
  end

  def fetch_connection_data
    begin
      ec2 = AWS::EC2::Client.new(aws_config)
      vpn_info = ec2.describe_vpn_connections(vpn_connection_ids: [config[:vpn_id]]).vpn_connection_set
      down_connections = vpn_info.first.vgw_telemetry.select { |x| x.status != 'UP' }
      results = { down_count: down_connections.count }
      results[:down_connection_status] = down_connections.map { |x| "#{x.outside_ip_address} => #{x.status_message.nil? ? 'none' : x.status_message}" }
      results[:connection_name] = vpn_info[0].tag_set.find { |x| x.key == 'Name' }.value
    rescue AWS::EC2::Errors::InvalidVpnConnectionID::NotFound
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
      Not sure this could ever happen
      unknown "Unknown connection count - #{data[:down_count]}"
    end
  end
end
