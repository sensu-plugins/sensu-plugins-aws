#! /usr/bin/env ruby
#
# check-ebs-snapshots
#
# DESCRIPTION:
#   Alert on new eip allocations
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
#   ./check-eip-allocation.rb -r ${you_region} -e ${eips_allowed}
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

class CheckEipAllocation < Sensu::Plugin::Check::CLI
  include Common
  option :eips_allowed,
         short:       '-e EIPS_ALLOWED',
         long:        '--eips_allowed eip1,eip2',
         required: 	  true,
         description: 'List of EIPs that are allowed to exist.  Comma seperated.'

  option :aws_region,
         short:       '-r R',
         long:        '--region REGION',
         description: 'AWS region',
         default: 'us-east-1'

  def run
    errors = []
    ec2 = Aws::EC2::Client.new

    eips = ec2.describe_addresses
    eips[:addresses].each do |eip|
      unless config[:eips_allowed].include? eip.public_ip
        errors << eip.public_ip
      end
    end

    if errors.empty?
      ok
    else
      warning errors.join("\n")
    end
  end
end
