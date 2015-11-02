#! /usr/bin/env ruby
#
# check-ec2-instance-status
#
# DESCRIPTION:
#   This plugin checks for EC2 instances failing status checks
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: aws-sdk-core
#   gem: sensu-plugin
#
# USAGE:
#   check-ec2-instance-status.rb -a aws_access_key -k aws_secret_key -r aws_region
#
# NOTES:
#
# LICENSE:
#   Copyright 2015, Eric Heydrick <eheydrick@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'aws-sdk-core'

# Check EC2 instance status
class CheckInstanceStatus < Sensu::Plugin::Check::CLI
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

  def aws_config
    { access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key],
      region: config[:aws_region]
    }
  end

  def run
    ec2 = Aws::EC2::Client.new(aws_config)

    impaired_instances = []
    begin
      ec2.describe_instance_status.instance_statuses.each do |instance|
        if instance[:system_status][:status] == 'impaired' || instance[:instance_status][:status] == 'impaired'
          impaired_instances << instance[:instance_id]
        end
      end
    rescue => e
      unknown "Unable to call the EC2 API: #{e.message}"
    end

    if impaired_instances.size > 0
      critical "One or more instances are impaired: #{impaired_instances.join(',')}"
    else
      ok 'All status checks passing'
    end
  end
end
