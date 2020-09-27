#! /usr/bin/env ruby
#
# check-vpc-nameservers
#
# DESCRIPTION:
#   Checks the VPCs nameservers are functional
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
#   ./check-vpc-nameservers.rb -v vpc-12345678
#   ./check-vpc-nameservers.rb -v vpc-12345678 -r us-east-1
#   ./check-vpc-nameservers.rb -v vpc-12345678 -r us-east-1 -q google.com,internal.private.servers
#
# NOTES:
#
# LICENSE:
#   Shane Starcher <shane.starcher@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'sensu-plugins-aws'
require 'aws-sdk'
require 'resolv'

class CheckVpcNameservers < Sensu::Plugin::Check::CLI
  include Common
  option :queries,
         short:       '-q queries',
         long:        '--queries google.com,example1.com',
         proc:        proc { |a| a.split(',') },
         default:     ['google.com'],
         description: 'Comma seperated dns queries to test'

  option :vpc_id,
         short:       '-v vpc_id',
         long:        '--vpc_id vpc-12345678',
         required:    true,
         description: 'The vpc_id of the dhcp option set'

  option :aws_region,
         short:       '-r R',
         long:        '--region REGION',
         description: 'AWS region',
         default: 'us-east-1'

  def run
    errors = []
    ec2 = Aws::EC2::Client.new

    dhcp_option_id = ec2.describe_vpcs(vpc_ids: [config[:vpc_id]]).vpcs[0].dhcp_options_id

    options = ec2.describe_dhcp_options(dhcp_options_ids: [dhcp_option_id])

    options.dhcp_options.each do |option|
      option.dhcp_configurations.each do |map|
        next if map.key != 'domain-name-servers'
        map.values.each do |value| # rubocop:disable Performance/HashEachMethods
          ip = value.value
          config[:queries].each do |query|
            begin
              Resolv::DNS.open(nameserver: [ip]).getaddress(query)
            rescue Resolv::ResolvError => res_err
              errors << "[#{ip}] #{res_err} "
            end
          end
        end
      end
    end

    if errors.empty?
      ok
    else
      warning errors.join("\n")
    end
  end
end
