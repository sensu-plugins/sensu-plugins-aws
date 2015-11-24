#! /usr/bin/env ruby
#
# check-beanstalk-health
#
# DESCRIPTION:
#   This plugin checks the health of a beanstalk environment using
#   the enhanced health reporting.
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
#   ./check-beanstalk-health -e MyAppEnv
#
# NOTES:
#
# LICENSE:
#   Brendan Leon Gibat
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'aws-sdk'

class BeanstalkHealth < Sensu::Plugin::Check::CLI

  option :environment,
        description: 'Application environment name',
        short: '-e ENVIRONMENT_NAME',
        long: '--environment ENVIRONMENT_NAME',
        required: true

  option :no_data_ok,
        short: '-n',
        long: '--allow-no-data',
        description: 'Returns unknown if health status is Grey. If set to false this will critical on a Grey status.',
        boolean: true,
        default: true

  def env_health
    @elb_name ||= Aws::ElasticBeanstalk::Client.new
      .describe_environment_health({environment_name: config[:environment]})
      .status
  end

  def run
    health = env_health
    if health == "Green"
      ok
    elsif health == "Yellow"
      warning "Environment status is YELLOW"
    elsif health == "Red"
      critical "Environment status is RED"
    elsif health == "Grey"
      if config[:no_data_ok]
        unknown "Environment status is GREY"
      else
        critical "Environment status is GREY"
      end
    else
      critical "Unknown Environment status response, #{health}"
    end
  end
end
