#!/usr/bin/env ruby
#
# CHANGELOG:
# * 0.7.0:
#   - Added method get_instance_id to check in client config section
#     ['client']['aws']['instance_id'] first.
# * 0.6.0:
#   - Fixed ec2_node_should_be_deleted to account for an empty insances array
# * 0.5.0:
#   - Adds configuration to filter by state reason
# * 0.4.0:
#   - Adds ability to specify a list of states an individual client can have in
#     EC2. If none is specified, it filters out 'terminated' and 'stopped'
#     instances by default.
#   - Updates how we are "puts"-ing to the log.
# * 0.3.0:
#   - Updates handler to additionally filter stopped instances.
# * 0.2.1:
#   - Updates requested configuration snippets so they'll be redacted by
#     default.
# * 0.2.0:
#   - Renames handler from chef_ec2_node to ec2_node
#   - Removes Chef-related stuff from handler
#   - Updates documentation
# * 0.1.0:
#   - Initial release
#
# This handler deletes a Sensu client if it's been stopped or terminated in EC2.
# Optionally, you may specify a client attribute `ec2_states`, a list of valid
# states an instance may have.
#
# You may also specify a client attribute `ec2_state_reasons`, a list of regular
# expressions to match state reasons against. This is useful if you want to fail
# on any `Client.*` state reason or on `Server.*` state reason. The default is
# to match any state reason `.*` Regardless, eventually a client will be
# deleted once AWS stops responding that the instance id exists.
#
# NOTE: The implementation for correlating Sensu clients to EC2 instances may
# need to be modified to fit your organization. The current implementation
# assumes that Sensu clients' names are the same as their instance IDs in EC2.
# If this is not the case, you can either sub-class this handler and override
# `ec2_node_should_be_deleted?` in your own organization-specific handler, or modify this
# handler to suit your needs.
#
#
# Optional a Sensu configuration snippet:
#   {
#     "aws": {
#       "access_key": "adsafdafda",
#       "secret_key": "qwuieohajladsafhj23nm",
#       "region": "us-east-1c"
#     }
#   }
#
# Or you can set the following environment variables:
#   - AWS_ACCESS_KEY_ID
#   - AWS_SECRET_ACCESS_KEY
#   - EC2_REGION
#
# If none of the settings are found it will then attempt to
# generate temporary credentials from the IAM instance profile
#
# If region is not specified in either of the above 2 mechanisms
# we will make a request for the EC2 instances current region.
#
# To use, you can set it as the keepalive handler for a client:
#   {
#     "client": {
#       "name": "i-424242",
#       "address": "127.0.0.1",
#       "keepalive": {
#         "handler": "ec2_node"
#       },
#       "subscriptions": ["all"]
#     }
#   }
#
# You can also use this handler with a filter:
#   {
#     "filters": {
#       "ghost_nodes": {
#         "attributes": {
#           "check": {
#             "name": "keepalive",
#             "status": 2
#           },
#           "occurences": "eval: value > 2"
#         }
#       }
#     },
#     "handlers": {
#       "ec2_node": {
#         "type": "pipe",
#         "command": "/etc/sensu/handlers/ec2_node.rb",
#         "severities": ["warning","critical"],
#         "filter": "ghost_nodes"
#       }
#     }
#   }
#
# Copyleft 2013 Yet Another Clever Name
#
# Based off of the `chef_node` handler by Heavy Water Operations, LLC
#
# Released under the same terms as Sensu (the MIT license); see
# LICENSE for details

require 'timeout'
require 'sensu-handler'
require 'net/http'
require 'uri'
require 'aws-sdk'
require 'sensu-plugins-aws'

class Ec2Node < Sensu::Handler
  include Common

  def filter; end

  def handle
    if ec2_node_should_be_deleted?
      delete_sensu_client!
    else
      puts "[EC2 Node] #{get_instance_id()} is in an invalid state"
    end
  end

  def delete_sensu_client!
    response = api_request(:DELETE, '/clients/' + get_instance_name()).code
    deletion_status(response)
  end

  def get_instance_id
    if @event['client'].has_key?("aws") && @event['client']['aws'].has_key?("instance_id")
      @event['client']['aws']['instance_id']
    else
      @event['client']['name']
    end
  end

  def get_instance_name
    @event['client']['name']
  end

  def ec2_node_should_be_deleted?
    ec2 = Aws::EC2::Client.new(region: region)
    states = @event['client']['ec2_states'] || settings['ec2_node']['ec2_states'] || ['shutting-down', 'terminated', 'stopping', 'stopped']
    begin
      instances = ec2.describe_instances(instance_ids: [get_instance_id()]).reservations[0]
      if instances.nil? || instances.empty?
        true
      else
        instance = instances.instances[0]
        state_reason = instance.state_reason.nil? ? nil : instance.state_reason.code
        state = instance.state.name
        states.include?(state) && state_reasons.any? { |reason| Regexp.new(reason) =~ state_reason }
      end
    rescue Aws::EC2::Errors::InvalidInstanceIDNotFound
      true
    end
  end

  def region
    @region ||= begin
      region_check = ENV['EC2_REGION']
      region_check = settings['aws']['region'] if settings.key? 'aws'
      if region_check.nil? || region_check.empty?
        region_check = Net::HTTP.get(URI('http://169.254.169.254/latest/meta-data/placement/availability-zone'))
        matches = /(\w+\-\w+\-\d+)/.match(region_check)
        if !matches.nil? && !matches.captures.empty?
          region_check = matches.captures[0]
        end
      end
      region_check
    end
  end

  def state_reasons
    default_reasons = %w('UserInitiatedShutdown', 'SpotInstanceTermination', 'InstanceInitiatedShutdown')
    reasons = @event['client']['ec2_state_reasons'] || settings['ec2_node']['ec2_state_reasons'] || default_reasons
    @state_reasons ||= reasons.each { |reason| Regexp.new(reason) }
  end

  def deletion_status(code)
    case code
    when '202'
      puts "[EC2 Node] 202: Successfully deleted Sensu client: #{get_instance_name()}"
    when '404'
      puts "[EC2 Node] 404: Unable to delete #{get_instance_name()}, doesn't exist!"
    when '500'
      puts "[EC2 Node] 500: Miscellaneous error when deleting #{get_instance_name()}"
    else
      puts "[EC2 Node] #{code}: Completely unsure of what happened!"
    end
  end
end
