#! /usr/bin/env ruby
#
# check-kms-key
#
# DESCRIPTION:
#   Check KMS values by KMS API.
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
#   check-kms-key -k key_id
#
#   Critical if KMS key id doesn't exist
#   Warning if KMS key id exists but is not enabled
#   Ok if KMS key id exists and is enabled
#   Unknown if no key_id is provided
#   Unknown if there is any error querying KMS
#
# NOTES:
#
# LICENSE:
#   Copyright 2016 github.com/jcastillocano
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'aws-sdk'

class CheckKMSKey < Sensu::Plugin::Check::CLI
  option :aws_access_key,
         short:       '-a AWS_ACCESS_KEY',
         long:        '--aws-access-key AWS_ACCESS_KEY',
         description: "AWS Access Key. Either set ENV['AWS_ACCESS_KEY'] or provide it as an option",
         default:     ENV['AWS_ACCESS_KEY']

  option :aws_secret_access_key,
         short:       '-k AWS_SECRET_KEY',
         long:        '--aws-secret-access-key AWS_SECRET_KEY',
         description: "AWS Secret Access Key. Either set ENV['AWS_SECRET_KEY'] or provide it as an option",
         default:     ENV['AWS_SECRET_KEY']

  option :aws_region,
         short:       '-r AWS_REGION',
         long:        '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default:     'us-east-1'

  option :key_id,
         short:       '-k ID',
         long:        '--key-id ID',
         description: 'KMS key identifier',
         default:     nil

  def aws_config
    { access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key],
      region: config[:aws_region]
    }
  end

  def aws_client(opts = {})
    config = aws_config.merge(opts)
    @aws_client ||= Aws::KMS::Client.new config
  end

  def check_key(id)
    return aws_client.describe_key(key_id: id)['key_metadata']['enabled']
  rescue Aws::KMS::Errors::NotFoundException
    puts 'Nop'
    critical 'Key doesnt exist'
  rescue => e
    puts "Failed to check key #{id}: #{e}"
    unknown "Failed to check key #{id}: #{e}"
  end

  def run
    if config[:key_id].nil?
      unknown 'No KMS key id provided.  See help for usage details'
    elsif check_key(config[:key_id])
      ok 'Key exists and is enabled'
    else
      warning 'Key exists but is not enabled'
    end
  end
end
