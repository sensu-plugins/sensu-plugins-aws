#!/usr/bin/env ruby
#
# check-route53-domain-expiration
#
# DESCRIPTION:
#   Alert when Route53 registered domains are close to expiration
#
# OUTPUT:
#   plain-text
#
# DEPENDENCIES:
#   gem: aws-sdk
#   gem: sensu-plugin
#
# USAGE:
#   check-route53-domain-expiration.rb
#
# LICENSE:
#   Eric Heydrick <eheydrick@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.

require 'sensu-plugins-aws'
require 'sensu-plugin/check/cli'
require 'aws-sdk'

class CheckRoute53DomainExpiration < Sensu::Plugin::Check::CLI
  include Common

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default: 'us-east-1'

  option :warn,
         short: '-w WARN',
         long: '--warning WARN',
         description: 'Warn if domain expires in less than this many days (default: 30)',
         default: 30,
         proc: proc(&:to_i)

  option :crit,
         short: '-c CRITICAL',
         long: '--critical CRITICAL',
         description: 'Critical if domain expires in less than this many days (default: 7)',
         default: 7,
         proc: proc(&:to_i)

  def run
    warn_domains = {}
    crit_domains = {}

    r53 = Aws::Route53Domains::Client.new(aws_config)
    begin
      domains = r53.list_domains.domains
      domains.each do |domain|
        expiration = DateTime.parse(domain.expiry.to_s) # rubocop: disable Style/DateTime
        days_until_expiration = (expiration - DateTime.now).to_i # rubocop: disable Style/DateTime
        if days_until_expiration <= config[:crit]
          crit_domains[domain] = days_until_expiration
        elsif days_until_expiration <= config[:warn]
          warn_domains[domain] = days_until_expiration
        end
      end

      if !crit_domains.empty?
        critical "Domains are expiring in less than #{config[:crit]} days: " + crit_domains.map { |d, v| "#{d.domain_name} (in #{v} days)" }.join(', ')
      elsif !warn_domains.empty?
        warning "Domains are expiring in less than #{config[:warn]} days: " + warn_domains.map { |d, v| "#{d.domain_name} (in #{v} days)" }.join(', ')
      else
        ok 'No domains are expiring soon'
      end
    rescue StandardError => e
      unknown "An error occurred communicating with the Route53 API: #{e.message}"
    end
  end
end
