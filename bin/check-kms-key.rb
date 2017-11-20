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
#
# NOTES:
#
# LICENSE:
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'sensu-plugins-aws'
require 'aws-sdk'

class CheckKMSKey < Sensu::Plugin::Check::CLI
  include Common

  option :aws_region,
         short:       '-r AWS_REGION',
         long:        '--aws-region REGION',
         description: 'AWS Region.',
         default: 'us-east-1'

  option :key_id,
         short:       '-k ID',
         long:        '--key-id ID',
         description: 'KMS key identifier',
         default:     nil

  def kms_client
    @kms_client ||= Aws::KMS::Client.new
  end

  def check_key(id)
    return kms_client.describe_key(key_id: id)['key_metadata']['enabled']
  rescue Aws::KMS::Errors::NotFoundException
    critical 'Key doesnt exist'
  rescue StandardError => e
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
