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
    @env_health ||= Aws::ElasticBeanstalk::Client.new
      .describe_environment_health({
          environment_name: config[:environment],
          attribute_names: ["Color", "Status", "HealthStatus", "Causes"]
          })
  end

  def status_rollup
    "Beanstalk Status: #{env_health.status}, Health Status: #{env_health.health_status}, Causes: #{env_health.causes.join(", ")}"
  end

  def run
    color = env_health.color
    if color == "Green"
      ok
    elsif color == "Yellow"
      warning "Environment status is YELLOW. #{status_rollup}"
    elsif color == "Red"
      critical "Environment status is RED. #{status_rollup}"
    elsif color == "Grey"
      if config[:no_data_ok]
        unknown "Environment status is GREY. This means NO DATA. #{status_rollup}"
      else
        critical "Environment status is GREY. This means NO DATA. #{status_rollup}"
      end
    else
      critical "Unknown Environment status response, #{color}"
    end
  end
end
