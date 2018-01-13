#! /usr/bin/env ruby
#
# check-ecs-service-health
#
# DESCRIPTION:
#   This plugin uses the AWS ECS API to check the running
#   and desired task counts for services on a cluster.
#   Any services with fewer running than desired tasks will
#   are considered unhealthy.
#
#   CRIT: 0 = running < desired
#   WARN: 0 < running < desired
#   OK:   running >= desired
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   Linux, Windows, Mac
#
# DEPENDENCIES:
#   gem: aws-sdk
#   gem: sensu-plugin
#
# USAGE:
#  ./check-ecs-service-health.rb -r {us-east-1|eu-west-1} -c default [-s my-service]
#
# NOTES:
#
# MULTIPLE CLUSTERS/SERVICES AUTOMATION
#   Create multiple clusters/services with these scripts: https://github.com/ay-b/ecs-service-check-autocreate
#   Don't forget to edit template file
#
# LICENSE:
#   Norm MacLennan <nmaclennan@cimpress.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.

require 'sensu-plugin/check/cli'
require 'sensu-plugins-aws'
require 'aws-sdk'

class CheckEcsServiceHealth < Sensu::Plugin::Check::CLI
  include Common

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region AWS_REGION',
         description: 'The AWS region in which to check rules. Currently only available in us-east-1.',
         default: 'us-east-1'

  option :cluster_name,
         short: '-c NAME',
         long: '--cluster-name NAME',
         description: 'The cluster to check services on.',
         default: 'default'

  option :services,
         short: '-s SERVICE',
         long: '--service NAME',
         description: 'The service to check run status on.'

  option :warn_as_crit,
         short: '-w',
         long: '--warn_as_crit',
         description: 'Consider it critical when any desired tasks are not running. Otherwise, only 0 is critical.'

  option :primary_status,
         short: '-p',
         long: '--primary_status',
         description: 'Checking for deployments which only have a Primary Status.',
         default: false

  def ecs_client
    @ecs_client ||= Aws::ECS::Client.new
  end

  # List of requested services or all services registered to the cluster
  def service_list(cluster = 'default', services = nil)
    return services.split ',' if services
    collect_services(cluster)
  end

  def collect_services(cluster = 'default', token: nil)
    response = ecs_client.list_services(cluster: cluster, next_token: token)
    services = response.service_arns
    services.push(*collect_services(cluster, token: response.next_token)) if response.next_token
    services
  end

  def service_details(cluster = 'default', services = nil)
    service_list(cluster, services).each_slice(10).to_a.map do |s|
      ecs_client.describe_services(cluster: cluster, services: s)['services']
    end.flatten
  end

  def bucket_service(running_count, desired_count)
    if running_count.zero? && desired_count > 0
      :critical
    elsif running_count < desired_count
      :warn
    else
      :ok
    end
  end

  # Unhealthy if service has fewer running tasks than desired
  def services_by_health(cluster = 'default', services = nil, primary_status = false)
    bucket = nil
    service_details(cluster, services).group_by do |service|
      if primary_status
        service.deployments.each do |x|
          if x[:status].include? 'PRIMARY'
            bucket = bucket_service(x[:running_count], x[:desired_count])
          end
        end
      else
        bucket = bucket_service(service[:running_count], service[:desired_count])
      end
      bucket
    end
  end

  def run
    service_healths = services_by_health(config[:cluster_name], config[:services], config[:primary_status])

    unhealthy = []
    unhealthy.concat(service_healths[:critical]) if service_healths.key? :critical
    unhealthy.concat(service_healths[:warn]) if service_healths.key? :warn

    if config[:primary_status]
      unhealthy_p = nil
      unhealthy = unhealthy.collect do |s|
        s.deployments.each do |x|
          if x[:status].include? 'PRIMARY'
            unhealthy_p = "#{s.service_name} (#{x.running_count}/#{x.desired_count})"
          end
        end
        unhealthy_p
      end
    else
      unhealthy = unhealthy.collect { |s| "#{s.service_name} (#{s.running_count}/#{s.desired_count})" }
    end

    if service_healths.key?(:critical) || (config[:warn_as_crit] && service_healths.key?(:warn))
      critical("Unhealthy ECS Services(Primary only = #{config[:primary_status]}):  #{unhealthy.join ', '}")
    elsif service_healths.key?(:warn)
      warning("Unhealthy ECS Services(Primary only = #{config[:primary_status]}): #{unhealthy.join ', '}")
    else
      ok
    end
  rescue StandardError => e
    unknown "An error occurred processing AWS ECS API: #{e.message}"
  end
end
