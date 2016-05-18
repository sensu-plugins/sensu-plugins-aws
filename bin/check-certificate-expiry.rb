#! /usr/bin/env ruby
#
# check-certificate-expiry
#
# DESCRIPTION:
#   Checks expiration date on certificate. If no certificate is passed it checks
#   all certs in account.  Will use default provider if no access key and secret are passed
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
#   ./check-certificate-expiry.rb --server-certificate-name ${cert_name} --warning 45 --critical 30
#
# NOTES:
#   Based heavily on Yohei Kawahara's check-ec2-network
#
# LICENSE:
#   Zach Bintliff <zbintliff@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'aws-sdk'

class CheckCertificateExpiry < Sensu::Plugin::Check::CLI
  option :aws_access_key,
         short:       '-a AWS_ACCESS_KEY',
         long:        '--aws-access-key AWS_ACCESS_KEY',
         description: "AWS Access Key. Either set ENV['AWS_ACCESS_KEY'] or provide it as an option. Uses Default Credential if none are passed",
         default:     ENV['AWS_ACCESS_KEY']

  option :aws_secret_access_key,
         short:       '-k AWS_SECRET_KEY',
         long:        '--aws-secret-access-key AWS_SECRET_KEY',
         description: "AWS Secret Access Key. Either set ENV['AWS_SECRET_KEY'] or provide it as an option. Uses Default Credential if none are passed",
         default:     ENV['AWS_SECRET_KEY']

  option :aws_region,
         short:       '-r AWS_REGION',
         long:        '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default:     'us-east-1'

  option :server_certificate_name,
         short:       '-n CERTIFICATE_NAME',
         long:        '--server-certificate-name CERTIFICATE_NAME',
         description: 'Certificate to check. Checks all if not passed'

  option :warning,
         short:       '-w N',
         long:        '--warning VALUE',
         description: 'Issue a warning if the Cert will expire in under VALUE days'

  option :critical,
         short:       '-c N',
         long:        '--critical VALUE',
         description: 'Issue a critical if the Cert will expire in under VALUE days',
         default:      0

  def aws_config
    { access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key],
      region: config[:aws_region] }
  end

  def aws_client(opts = {})
    config = aws_config.merge(opts)
    @aws_client ||= Aws::IAM::Client.new config
  end

  def get_cert(cert_name)
    aws_client.get_server_certificate(server_certificate_name: cert_name).server_certificate.server_certificate_metadata
  end

  def check_expiry(cert, reportstring, warnflag, critflag)
    expiration = cert.expiration.gmtime
    current_time = Time.now.gmtime
    time_to_expiry = (expiration - current_time).to_i / (24 * 60 * 60) ## Seconds to days, integer division

    if time_to_expiry <= config[:critical].to_i
      critflag = true
      reportstring += if time_to_expiry < 1
                        " #{cert.server_certificate_name} certificate is expired!"
                      else
                        " #{cert.server_certificate_name} certificate expires in #{time_to_expiry} days;"
                      end
    elsif time_to_expiry <= config[:warning].to_i
      warnflag = true
      reportstring += " #{cert.server_certificate_name} certificate expires in #{time_to_expiry} days;"
    end
    [reportstring, warnflag, critflag]
  end

  def run
    warnflag = false
    critflag = false
    reportstring = ''
    if config[:server_certificate_name].nil?
      aws_client.list_server_certificates.server_certificate_metadata_list.each do |cert|
        reportstring, warnflag, critflag = check_expiry(cert, reportstring, warnflag, critflag)
      end
    else
      reportstring, warnflag, critflag = check_expiry(get_cert(config[:server_certificate_name]), reportstring, warnflag, critflag)
    end

    if critflag
      critical reportstring
    elsif warnflag
      warning reportstring
    else
      ok 'All checked Certificates are ok'
    end
  end
end
