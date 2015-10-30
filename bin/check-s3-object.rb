#! /usr/bin/env ruby
#
# check-s3-bucket
#
# DESCRIPTION:
#   This plugin checks if a file exists in a bucket and/or is not too old.
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
#   ./check-s3-object.rb --bucket-name mybucket --aws-region eu-west-1 --use-iam --key-name "path/to/myfile.txt"
#   ./check-s3-object.rb --bucket-name mybucket --aws-region eu-west-1 --use-iam --key-name "path/to/myfile.txt" --warning 90000 --critical 126000
#   ./check-s3-object.rb --bucket-name mybucket --aws-region eu-west-1 --use-iam --key-name "path/to/myfile.txt" --warning 90000 --critical 126000 --ok-zero-size
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

  option :use_iam_role,
         short: '-u',
         long: '--use-iam',
         description: 'Use IAM role authenticiation. Instance must have IAM role assigned for this to work'

  option :bucket_name,
         short: '-b BUCKET_NAME',
         long: '--bucket-name',
         description: 'The name of the S3 bucket where object lives',
         required: true

  option :key_name,
         short: '-b KEY_NAME',
         long: '--key-name',
         description: 'The name of key in the bucket',
         required: true

  option :ok_zero_size,
         description: 'OK if file has zero size',
         short: '-z',
         long: '--ok-zero-size',
         boolean: true,
         default: false

  option :warning_age,
         description: 'Warn if mtime greater than provided age in seconds',
         short: '-w SECONDS',
         long: '--warning SECONDS'

  option :critical_age,
         description: 'Critical if mtime greater than provided age in seconds',
         short: '-c SECONDS',
         long: '--critical SECONDS'

  def aws_config
    { access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key],
      region: config[:aws_region]
    }
  end

  def run_check(type, age)
    to_check = config["#{type}_age".to_sym].to_i
    if to_check > 0 && age >= to_check # rubocop:disable GuardClause
      send(type, "S3 object #{config[:key_name]} is #{age - to_check} seconds past (bucket #{config[:bucket_name]})")
    end
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
      output = s3.head_object(bucket: config[:bucket_name], key: config[:key_name])

      if output[:content_length] == 0 && !config[:ok_zero_size]
        critical "S3 object #{config[:key_name]} has zero size (bucket #{config[:bucket_name]})"
      end

      if config[:warning_age] || config[:critical_age]
        age = Time.now.to_i - output[:last_modified].to_i
        run_check(:critical, age) || run_check(:warning, age) || ok("S3 object #{config[:key_name]} is #{age} seconds old (bucket #{config[:bucket_name]})")
      else
        ok("S3 object #{config[:key_name]} exists (bucket #{config[:bucket_name]})")
      end
    rescue Aws::S3::Errors::NotFound => _
      critical "S3 object #{config[:key_name]} not found in bucket #{config[:bucket_name]}"
    rescue => e
      critical "S3 object #{config[:key_name]} in bucket #{config[:bucket_name]} - #{e.message}"
    end
  end
end
