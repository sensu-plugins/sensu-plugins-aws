#! /usr/bin/env ruby
#
# check-elasticache-events
#
#
# DESCRIPTION:
#   This plugin checks ElastiCache clusters for critical events.
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
#  ./check-elasticache-events.rb -c <cache_cluster_id> -t <event_type> -r <region>
#
# NOTES:
#   There is a difference on how AWS define cache_cluster_id for clusters in a replication group.
#   For memcached and single-node Redis clusters, cache_cluster_id matches the cluster name.
#   For Redis clusters in a replication group, cache_cluster_id matches the cache node name. The cluster
#   name matches replication_group_id instead.
#
# LICENSE:
#   Seandy Wibowo <swibowo@sugarcrm.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.

require 'sensu-plugin/check/cli'
require 'sensu-plugins-aws'
require 'aws-sdk'
require 'time'

class CheckElastiCacheEvents < Sensu::Plugin::Check::CLI
  include Common
  option :aws_region,
         short:       '-r AWS_REGION',
         long:        '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default:     'us-east-1'

  option :cache_cluster_id,
         short:       '-c N',
         long:        '--cache-cluster-id NAME',
         description: 'ElastiCache cluster identifier (Name)'

  option :cache_event_type,
         short:       '-t T',
         long:        '--cache-event-type TYPE',
         description: 'ElastiCache event type'

  def cache_regions
    Aws.partition('aws').regions.map(&:name)
  end

  def run
    clusters_events = []
    desc_events_opts = {}
    # fetch the last 15 minutes of events for each cluster
    # that way, we're only spammed with persistent notifications that we'd care about.
    desc_events_opts[:start_time] = (Time.now - 900).iso8601
    desc_events_opts[:source_identifier] = config[:cache_cluster_id] if !config[:cache_cluster_id].nil? && !config[:cache_cluster_id].empty?
    desc_events_opts[:source_type] = config[:cache_event_type] if !config[:cache_event_type].nil? && !config[:cache_event_type].empty?

    aws_regions = cache_regions
    unless config[:aws_region].casecmp('all').zero?
      if aws_regions.include? config[:aws_region]
        aws_regions.clear.push(config[:aws_region])
      else
        critical 'Invalid region specified!'
      end
    end

    aws_regions.each do |r|
      begin
        elasticache = Aws::ElastiCache::Client.new(region: r)

        events_records = elasticache.describe_events(desc_events_opts)
        next if events_records[:events].empty?

        events_records[:events].each do |event_record|
          event_message = "#{event_record[:source_identifier]} (#{r}) #{event_record[:message]}"
          clusters_events.push(event_message)
        end
      rescue => e
        unknown "An error occurred processing AWS ElastiCache API (#{r}): #{e.message}"
      end
    end

    if clusters_events.empty?
      ok
    else
      critical("Clusters with Critical Events: #{clusters_events.join(', ')}")
    end
  end
end
