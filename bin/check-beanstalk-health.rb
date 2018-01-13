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
require 'json'

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

  option :aws_region,
         short:       '-r AWS_REGION',
         long:        '--aws-region REGION',
         description: 'Optional parameter to specify AWS Region.'

  def env_health
    @env_health ||= beanstalk_client
                    .describe_environment_health(
                      environment_name: config[:environment],
                      attribute_names: %w[Color Status HealthStatus Causes]
                    )
  end

  def beanstalk_client
    @beanstalk_client ||= if config[:aws_region]
                            Aws::ElasticBeanstalk::Client.new(
                              region: config[:aws_region]
                            )
                          else
                            Aws::ElasticBeanstalk::Client.new
                          end
  end

  def instances_health
    @instances_health ||= begin
      curr_instances = beanstalk_client.describe_instances_health(
        environment_name: config[:environment],
        attribute_names: %w[Color HealthStatus Causes]
      )
      instances = curr_instances.instance_health_list
      until curr_instances.next_token.nil?
        curr_instances = beanstalk_client.describe_instances_health(
          environment_name: config[:environment],
          attribute_names: %w[Color HealthStatus Causes]
        )
        instances.concat(curr_instances.instance_health_list)
      end
      instances
    end
  end

  def unhealthy_instances
    @unhealthy_instances ||= instances_health.reject { |i| i.color == 'Green' }
  end

  def status_rollup
    "Beanstalk Status: #{env_health.status}, Health Status: #{env_health.health_status}, Causes: #{env_health.causes.join(', ')}"
  end

  def unhealthy_instance_description(instance)
    "instance id: #{instance.instance_id}, color: #{instance.color}, health status: #{instance.health_status}, causes: [#{instance.causes.join(', ')}]"
  end

  def unhealthy_instances_rollup
    "Unhealthy instances and causes: [ #{unhealthy_instances.collect { |i| unhealthy_instance_description(i) }.join(', ')} ]"
  end

  def run
    color = env_health.color
    if color == 'Green'
      ok
    elsif color == 'Yellow'
      warning "Environment status is YELLOW. #{status_rollup} #{unhealthy_instances_rollup}"
    elsif color == 'Red'
      critical "Environment status is RED. #{status_rollup} #{unhealthy_instances_rollup}"
    elsif color == 'Grey'
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
