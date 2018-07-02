#! /usr/bin/env ruby
#
# check-elb-instances-endpoints
#
# DESCRIPTION:
#   This plugin checks for a HTTP 200 against each instance attached to a ELB.
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
#
#   Check each instance on the elb returns a HTTP200 on the path /
#   check-elb-instances-endpoints.rb -n ELBNAME -p /
#
#   Check each instance on the elb returns a HTTP200 on the path / and use https
#   check-elb-instances-endpoints.rb -n ELBNAME -p / -s
#
#   Check each instance on the elb returns a HTTP200 on the path / using port 8080
#   check-elb-instances-endpoints.rb -n ELBNAME -p / -P 8080
#
#   Check each instance on the elb returns a HTTP200 on the path / in a given AWS region
#   check-elb-instances-endpoints.rb -n ELBNAME -p / -r eu-west-1
#
# LICENSE:
#    MIT License
#
#    Copyright (c) 2017 Claranet
#
#    Permission is hereby granted, free of charge, to any person obtaining a copy
#    of this software and associated documentation files (the "Software"), to deal
#    in the Software without restriction, including without limitation the rights
#    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#    copies of the Software, and to permit persons to whom the Software is
#    furnished to do so, subject to the following conditions:
#
#    The above copyright notice and this permission notice shall be included in all
#    copies or substantial portions of the Software.
#
#    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#    SOFTWARE.
#

require 'sensu-plugin/check/cli'
require 'aws-sdk-v1'

# check each node by calling a http endpoint
class HTTPCheckELBNodes < Sensu::Plugin::Check::CLI
  option :aws_access_key,
         short: '-a AWS_ACCESS_KEY',
         long: '--aws-access-key AWS_ACCESS_KEY',
         description: "AWS Access Key. or use ENV['AWS_ACCESS_KEY']",
         default: ENV['AWS_ACCESS_KEY']

  option :aws_secret_access_key,
         short: '-k AWS_SECRET_KEY',
         long: '--aws-secret-access-key AWS_SECRET_KEY',
         description: "AWS Secret Access Key or use ENV['AWS_SECRET_KEY']",
         default: ENV['AWS_SECRET_KEY']

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (defaults to eu-west-1)',
         default: 'eu-west-1'

  option :instance_name,
         short: '-n ELB_NAME',
         long: '--name ELB_NAME',
         description: 'Regular expression to describe the elb name',
         required: true

  option :path,
         short: '-p PATH',
         long: '--path PATH',
         description: 'path to check',
         required: true

  option :use_http,
         long: '--http',
         description: 'use http (default: false)',
         boolean: true,
         default: false

  option :port,
         short: '-P PORT',
         long: '--port PORT',
         description: 'HTTP port',
         default: 0,
         proc: proc(&:to_i)

  option :timeout,
         long: '--timeout TIMEOUT',
         description: 'HTTP timeout',
         default: 2,
         proc: proc(&:to_i)

  option :private_dns,
         long: '--private-dns',
         description: 'Use the private DNS name (default is the public dns)',
         default: false,
         boolean: true

  option :response_code,
         long: '--response-code',
         description: 'Expected response code (default HTTP200)',
         default: '200'

  def aws_config
    { access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key],
      region: config[:aws_region] }
  end

  def run
    instances = get_instances((AWS::ELB.new aws_config))
    errors = {}

    instances.each do |inst|
      resp = call_endpoint(inst)
      errors[inst.id] = resp unless resp.nil?
    end.empty? && begin
      errors['amount'] = 'zero instances found'
    end

    errors.keys.count.zero? ? (ok 'all is good') : (critical errors.to_s)
  end

  def get_instances(elbs)
    instances = []
    elbs.load_balancers.each do |elb|
      elb.instances.each { |instance| instances << instance if /#{config[:instance_name]}/ =~ instance.tags['Name'] }
    end
    instances
  rescue => e
    unknown "retrieving load balancer describtors: #{e}"
  end

  def name
    config[:load_balancer_name]
  end

  def call_endpoint(inst)
    url = URI("#{schema}://#{host(inst)}#{port}#{path}")
    http = Net::HTTP.new(url.host, url.port)
    http.read_timeout = timeout
    http.open_timeout = timeout
    resp = http.start { |session| session.get(url.path) }
    invalid_code = resp.code != response_code
    return 'Page not found' if invalid_code && resp.code == '404'
    return 'Invalid status' if invalid_code && resp.body.empty?
    return resp.body if invalid_code
    nil
  rescue
    'Timeout'
  end

  def host(inst)
    private_dns ? inst.private_dns_name : inst.public_dns_name
  end

  def private_dns
    config[:private_dns]
  end

  def timeout
    config[:timeout]
  end

  def schema
    config[:use_http] ? 'http' : 'https'
  end

  def port
    config[:port].zero? ? '' : ":#{config[:port]}"
  end

  def path
    config[:path]
  end

  def response_code
    config[:response_code]
  end
end
