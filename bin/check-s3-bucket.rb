#! /usr/bin/env ruby
#
# check-s3-bucket
#
# DESCRIPTION:
#   This plugin checks a bucket and alerts if not exists
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
#   ./check-s3-bucket.rb --bucket-name mybucket --aws-region eu-west-1
#
# NOTES:
#
# LICENSE:
#   Copyright (c) 2015, Olivier Bazoud, olivier.bazoud@gmail.com
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'aws-sdk'

class CheckS3Bucket < Sensu::Plugin::Check::CLI
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

  option :bucket_name,
         short: '-b BUCKET_NAME',
         long: '--bucket-name',
         description: 'The name of the S3 bucket to check',
         required: true

  option :use_iam_role,
         short: '-u',
         long: '--use-iam',
         description: 'Use IAM role authenticiation. Instance must have IAM role assigned for this to work'

  def aws_config
    { access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key],
      region: config[:aws_region]
    }
  end

  def run
    aws_config = {}

    if config[:use_iam_role].nil?
      aws_config.merge!(
        access_key_id: config[:aws_access_key],
        secret_access_key: config[:aws_secret_access_key]
      )
    end

    s3 = Aws::S3::Client.new(aws_config.merge!(region: config[:aws_region]))
    begin
      s3.head_bucket(bucket: config[:bucket_name])
      ok "Bucket #{config[:bucket_name]} found"
    rescue Aws::S3::Errors::NotFound => _
      critical "Bucket #{config[:bucket_name]} not found"
    rescue => e
      critical "Bucket #{config[:bucket_name]} - #{e.message}"
    end
  end
end
