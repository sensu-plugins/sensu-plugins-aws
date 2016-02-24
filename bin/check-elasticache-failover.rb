#! /usr/bin/env ruby
#
#   check-elasticache-failover.rb
#
# DESCRIPTION:
#   Checks if specified ElastiCache node is `primary` state.
#
# OUTPUT:
#   CheckElastiCacheFailover OK: Node `mynode-001` (in replication group `my-group-1`, node group `0001`) is `primary`.
#   or
#   CheckElastiCacheFailover CRITICAL: Node `mynode-001` (in replication group `my-group-1`, node group `0001`) is **not** `primary`.
#
# PLATFORMS:
#   Linux, Windows, BSD, Solaris, etc
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: aws-sdk >= 2
#
# USAGE:
#   check-elasticache-failover.rb --region <your region> --replication-group <yours> --node-group <yours> --primary-node <yours>
#
# NOTES:
#
# LICENSE:
#   y13i <email@y13i.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'aws-sdk'
require 'sensu-plugins-aws/common'

class CheckElastiCacheFailover < Sensu::Plugin::Check::CLI
  VERSION = '0.0.1'.freeze

  option :profile,
         description: 'Profile name of AWS shared credential file entry.',
         long:        '--profile PROFILE',
         short:       '-p PROFILE'

  option :aws_region,
         description: 'AWS region.',
         short:       '-r REGION',
         long:        '--region REGION'

  option :severity,
         description: 'Critical or Warning.',
         short:       '-s SEVERITY',
         long:        '--severity SEVERITY',
         proc:        :intern.to_proc,
         default:     :critical

  option :replication_group,
         description: 'Replication group to check.',
         long:        '--replication-group ID',
         short:       '-g ID'

  option :node_group,
         description: 'Node group to check.',
         long:        '--node-group ID',
         short:       '-n ID'

  option :primary_node,
         description: 'Cluster name that should be primary.',
         long:        '--primary-node NAME',
         short:       '-c NAME'

  include Common

  def run
    replication_group = elasticache.client.describe_replication_groups.replication_groups.find do |g|
      g.replication_group_id == config[:replication_group]
    end

    unknown 'Replication group not found.' if replication_group.nil?

    node_group = replication_group.node_groups.find do |g|
      g.node_group_id == config[:node_group]
    end

    unknown 'Node group not found.' if node_group.nil?

    node = node_group.node_group_members.find do |n|
      n.cache_cluster_id == config[:primary_node]
    end

    unknown 'Node not found.' if node.nil?

    message = "Node `#{config[:primary_node]}` (in replication group `#{config[:replication_group]}`, node group `#{config[:node_group]}`) is "

    if node.current_role == 'primary'
      message += '`primary`.'
      ok message
    else
      message += '**not** `primary`.'
      send config[:severity], message
    end
  end

  private

  def elasticache
    return @elasticache if @elasticache

    c = {}
    c.update aws_config
    c.update(profile: config[:profile]) if config[:profile]

    @elasticache = Aws::ElastiCache::Resource.new(c)
  end
end
