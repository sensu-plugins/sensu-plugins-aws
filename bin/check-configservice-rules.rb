#! /usr/bin/env ruby
#
# check-configservice-rules
#
# DESCRIPTION:
#   This plugin uses the AWS ConfigService API to check
#   for rules compliance. CRITICAL for non-compliance,
#   UNKNOWN for insufficient data.
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
#  ./check-configservice-rules.rb -r {us-east-1|eu-west-1} [-c My_Config_Rule]
#
# NOTES:
#   As of this writing, ConfigService rules are only available in us-east-1.
#   All other region selections will return an AccessDeniedException
#
# LICENSE:
#   Norm MacLennan <nmaclennan@cimpress.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.

require 'sensu-plugin/check/cli'
require 'sensu-plugins-aws'
require 'aws-sdk'

class CheckConfigServiceRules < Sensu::Plugin::Check::CLI
  include Common

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region AWS_REGION',
         description: 'The AWS region in which to check rules. Currently only available in us-east-1.',
         default: 'us-east-1'

  option :config_rules,
         short: '-c rule1,rule2',
         long: '--config-rules rule1,rule2',
         description: 'A list of config rules to consider. Default is all rules.'

  def get_config_rules_data(rules = nil)
    options = { config_rule_names: rules.split(',') } if rules
    config_client = Aws::ConfigService::Client.new
    config_client.describe_compliance_by_config_rule(options).compliance_by_config_rules
  end

  def get_rule_names_by_compliance_type(rules, compliance_type)
    rules.select { |r| r.compliance.compliance_type == compliance_type }.collect(&:config_rule_name)
  end

  def run
    rules = get_config_rules_data(config[:config_rules])

    noncompliant = get_rule_names_by_compliance_type rules, 'NON_COMPLIANT'
    unknown = get_rule_names_by_compliance_type rules, 'INSUFFICIENT_DATA'

    if noncompliant.any?
      critical("Config rules in violation: #{noncompliant.join(',')}")
    elsif unknown.any?
      unknown("Config rules in unknown state: #{unknown.join(',')}")
    else
      ok
    end
  rescue StandardError => e
    unknown "An error occurred processing AWS ConfigService API: #{e.message}"
  end
end
