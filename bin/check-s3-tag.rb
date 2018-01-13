#! /usr/bin/env ruby
#
# check-s3-tag
#
# DESCRIPTION:
#   This plugin checks if buckets have a set of tags.
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
#   ./check-s3-tag.rb --aws-region eu-west-1 --tag-keys xxx
#
# NOTES:
#
# LICENSE:
#   Copyright (c) 2016, Olivier Bazoud, olivier.bazoud@gmail.com
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'sensu-plugins-aws/common'
require 'aws-sdk'

class CheckS3Tag < Sensu::Plugin::Check::CLI
  include Common

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default: 'us-east-1'

  option :tag_keys,
         short: '-t TAG_KEYS',
         long: '--tag-keys TAG_KEYS',
         description: 'Tag keys'

  def run
    tags = config[:tag_keys].split(',')
    s3 = Aws::S3::Client.new
    missing_tags = []
    s3.list_buckets.buckets.each do |bucket|
      begin
        keys = s3.get_bucket_tagging(bucket: bucket.name).tag_set.map(&:key)
        if keys.sort & tags.sort != tags.sort
          missing_tags.push bucket.name
        end
      rescue StandardError
        missing_tags.push bucket.name
      end
    end

    if missing_tags.empty?
      ok
    else
      critical("Missing tags in #{missing_tags}")
    end
  rescue StandardError => e
    critical "Error: #{e.message} - #{e.backtrace}"
  end
end
