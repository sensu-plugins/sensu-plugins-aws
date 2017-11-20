#! /usr/bin/env ruby
#
# metrics-autoscaling-instance-count
#
# DESCRIPTION:
#   Get a count of instances in a given AutoScaling group
#
# OUTPUT:
#   metric-data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: aws-sdk-v1
#   gem: sensu-plugin
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright 2013 Bashton Ltd http://www.bashton.com/
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/metric/cli'
require 'aws-sdk'

class AutoScalingInstanceCountMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :groupname,
         description: 'Name of the AutoScaling group',
         short: '-g GROUP_NAME',
         long: '--autoscaling-group GROUP_NAME',
         default: false

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: ''

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

  option :include_name,
         short: '-n',
         long: '--include-name',
         description: "Includes any offending instance's 'Name' tag in the metric output",
         default: false

  def aws_config
    { access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key],
      region: config[:aws_region] }
  end

  def autoscaling_groups
    client = Aws::AutoScaling::Client.new(aws_config)
    client.describe_auto_scaling_groups[:auto_scaling_groups].map(&:auto_scaling_group_name)
  end

  def run
    begin
      groupnames ||= config[:groupname] ? [config[:groupname]] : autoscaling_groups
      groupnames.each do |g|
        as = Aws::AutoScaling::AutoScalingGroup.new aws_config.merge!(name: g)
        count = as.instances.map(&:lifecycle_state).count('InService')
        scheme_name ||= config[:include_name] ? as.data[:tags].select { |tag| tag[:key] == 'Name' }[0][:value] : g
        graphitepath =
          if config[:scheme] == ''
            "#{scheme_name}.autoscaling.instance_count"
          else
            "#{config[:scheme]}.#{scheme_name}.instance_count"
          end
        output graphitepath, count
      end
    rescue StandardError => e
      puts "Error: exception: #{e}"
      critical
    end
    ok
  end
end
