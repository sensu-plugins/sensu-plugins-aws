#! /usr/bin/env ruby
#
# check-beanstalk-elb-metric
#
# DESCRIPTION:
#   This plugin finds the desired ELB in a beanstalk environment and queries
#   for the requested cloudwatch metric for that ELB
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
#   ./check-beanstalk-elb-metric -e MyAppEnv -m Latency -c 100
#
# NOTES:
#
# LICENSE:
#   Andrew Matheny
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugins-aws/cloudwatch-common'
require 'sensu-plugin/check/cli'
require 'aws-sdk'

class BeanstalkELBCheck < Sensu::Plugin::Check::CLI
  option :environment,
         description: 'Application environment name',
         short: '-e ENVIRONMENT_NAME',
         long: '--environment ENVIRONMENT_NAME',
         required: true

  option :elb_idx,
         description: 'Index of ELB.  Useful for multiple ELB environments',
         short: '-i ELB_NUM',
         long: '--elb-idx ELB_NUM',
         default: 0,
         proc: proc(&:to_i)

  option :metric_name,
         description: 'ELB CloudWatch Metric',
         short: '-m METRIC_NAME',
         long: '--metric METRIC_NAME',
         required: true

  option :period,
         description: 'CloudWatch metric statistics period. Must be a multiple of 60',
         short: '-p N',
         long: '--period SECONDS',
         default: 60,
         proc: proc(&:to_i)

  option :statistics,
         short: '-s N',
         long: '--statistics NAME',
         default: 'Average',
         description: 'CloudWatch statistics method'

  option :unit,
         short: '-u UNIT',
         long: '--unit UNIT',
         description: 'CloudWatch metric unit'

  option :critical,
         description: 'Trigger a critical when value is over VALUE',
         short: '-c VALUE',
         long: '--critical VALUE',
         proc: proc(&:to_f),
         required: true

  option :warning,
         description: 'Trigger a warning when value is over VALUE',
         short: '-w VALUE',
         long: '--warning VALUE',
         proc: proc(&:to_f)

  option :compare,
         description: 'Comparision operator for threshold: equal, not, greater, less',
         short: '-o OPERATION',
         long: '--operator OPERATION',
         default: 'greater'

  option :no_data_ok,
         short: '-n',
         long: '--allow-no-data',
         description: 'Returns ok if no data is returned from the metric',
         boolean: true,
         default: false

  include CloudwatchCommon

  def metric_desc
    @metric_desc ||= "BeanstalkELB/#{config[:environment]}/#{elb_name}/#{config[:metric_name]}"
  end

  def elb_name
    @elb_name ||= Aws::ElasticBeanstalk::Client.new
                                               .describe_environment_resources(environment_name: config[:environment])
                                               .environment_resources
                                               .load_balancers[config[:elb_idx]]
                                               .name
  end

  def run
    new_config = config.clone
    new_config[:namespace] = 'AWS/ELB'
    new_config[:dimensions] = [
      {
        name: 'LoadBalancerName',
        value: elb_name
      }
    ]
    check new_config
  end
end
