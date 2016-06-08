require 'aws-sdk'
require_relative '../../bin/check-certificate-expiry.rb'
require_relative '../spec_helper.rb'

class CheckCertificateExpiry
  at_exit do
    @@autorun = false
  end

  def critical(*)
    'triggered critical'
  end

  def warning(*)
    'triggered warning'
  end

  def ok(*)
    'triggered ok'
  end
end

describe 'CheckCertificateExpiry' do
  before :all do
    @aws_stub = Aws::IAM::Client.new(stub_responses: true, region: 'us-east-1')
    # 360 is a hack to add 6 minutes to allow tests to run so it will always be
    # 14 days ahead
    @time_two_weeks = Time.new.gmtime.round(0) + (24 * 60 * 60 * 14) + 360
    @certificate_data =
      {
        server_certificate: {
          server_certificate_metadata: {
            server_certificate_name: 'my_test_cert',
            expiration: @time_two_weeks,
            path: 'path',
            server_certificate_id: 'abc-123',
            arn: 'aws::arn::boop'
          },
          certificate_body: 'test_body'
        }
      }
  end

  describe '#aws_config' do
    it 'should return only region' do
      check = CheckCertificateExpiry.new
      config = check.aws_config
      expect(config).to eq(access_key_id: nil, secret_access_key: nil, region: 'us-east-1')
    end
  end

  describe '#aws_client' do
    it 'should return a client' do
      check = CheckCertificateExpiry.new
      options = { stub_responses: true }
      client = check.aws_client(options)
      expect(client.config.stub_responses).to eq(true)
      expect(client.config.region).to eq('us-east-1')
    end
    it 'should return a client with west region' do
      check = CheckCertificateExpiry.new
      options = { stub_responses: true, region: 'us-west-2' }
      client = check.aws_client(options)
      expect(client.config.stub_responses).to eq(true)
      expect(client.config.region).to eq('us-west-2')
    end
  end

  describe '#get_cert' do
    it 'should return metadata' do
      check = CheckCertificateExpiry.new
      @aws_stub.stub_responses(:get_server_certificate, @certificate_data)
      allow(check).to receive(:aws_client).and_return(@aws_stub)
      cert_metadata = check.get_cert('testing')
      expect(@time_two_weeks).to eq(cert_metadata.expiration)
    end
  end

  describe '#check_expiry' do
    it 'should not trigger warnings or criticals' do
      check = CheckCertificateExpiry.new

      # Next three lines are needed to get Aws::IAM:Types::ServerCertificateMetadata object
      @aws_stub.stub_responses(:get_server_certificate, @certificate_data)
      allow(check).to receive(:aws_client).and_return(@aws_stub)
      cert_metadata = check.get_cert('testing')

      reportstring, warnflag, critflag = check.check_expiry(cert_metadata, 'should_not_mutate', false, false)
      expect(warnflag).to equal(false)
      expect(critflag).to equal(false)
      expect(reportstring).to eq('should_not_mutate')
    end

    it 'should trigger warning flag' do
      check = CheckCertificateExpiry.new('--warning 14'.split(' '))

      # Next three lines are needed to get Aws::IAM:Types::ServerCertificateMetadata object
      @aws_stub.stub_responses(:get_server_certificate, @certificate_data)
      allow(check).to receive(:aws_client).and_return(@aws_stub)
      cert_metadata = check.get_cert('testing')

      reportstring, warnflag, critflag = check.check_expiry(cert_metadata, '', false, false)
      expect(warnflag).to equal(true)
      expect(critflag).to equal(false)
      expect(reportstring).to eq(' my_test_cert certificate expires in 14 days;')
    end

    it 'should trigger critical flag' do
      check = CheckCertificateExpiry.new('--critical 14'.split(' '))

      # Next three lines are needed to get Aws::IAM:Types::ServerCertificateMetadata object
      @aws_stub.stub_responses(:get_server_certificate, @certificate_data)
      allow(check).to receive(:aws_client).and_return(@aws_stub)
      cert_metadata = check.get_cert('testing')

      reportstring, warnflag, critflag = check.check_expiry(cert_metadata, '', false, false)
      expect(warnflag).to equal(false)
      expect(critflag).to equal(true)
      expect(reportstring).to eq(' my_test_cert certificate expires in 14 days;')
    end

    it 'should trigger only critflag' do
      check = CheckCertificateExpiry.new('--warning 14 --critical 14'.split(' '))

      # Next three lines are needed to get Aws::IAM:Types::ServerCertificateMetadata object
      @aws_stub.stub_responses(:get_server_certificate, @certificate_data)
      allow(check).to receive(:aws_client).and_return(@aws_stub)
      cert_metadata = check.get_cert('testing')

      reportstring, warnflag, critflag = check.check_expiry(cert_metadata, '', false, false)
      expect(warnflag).to equal(false)
      expect(critflag).to equal(true)
      expect(reportstring).to eq(' my_test_cert certificate expires in 14 days;')
    end
  end

  describe '#run' do
    it 'should run and exit ok when passed nothing' do
      check = CheckCertificateExpiry.new
      @aws_stub.stub_responses(:list_server_certificates, server_certificate_metadata_list: [@certificate_data[:server_certificate][:server_certificate_metadata]])
      # only Testing run method, aws_client and expiry are tested elsewhere
      allow(check).to receive(:aws_client).and_return(@aws_stub)
      allow(check).to receive(:check_expiry).and_return(['', false, false])
      response = check.run
      expect(response).to eq('triggered ok')
    end

    it 'should run and exit with warning when nothing is passed' do
      check = CheckCertificateExpiry.new
      @aws_stub.stub_responses(:list_server_certificates, server_certificate_metadata_list: [@certificate_data[:server_certificate][:server_certificate_metadata]])
      allow(check).to receive(:aws_client).and_return(@aws_stub)
      allow(check).to receive(:check_expiry).and_return(['', true, false])
      response = check.run
      expect(response).to eq('triggered warning')
    end

    it 'should run and exit with critical when nothing is passed' do
      check = CheckCertificateExpiry.new
      @aws_stub.stub_responses(:list_server_certificates, server_certificate_metadata_list: [@certificate_data[:server_certificate][:server_certificate_metadata]])
      allow(check).to receive(:aws_client).and_return(@aws_stub)
      allow(check).to receive(:check_expiry).and_return(['', false, true])

      # Make sure we are executing the correct block
      expect(check).to receive(:aws_client)
      response = check.run
      expect(response).to eq('triggered critical')
    end

    it 'should run and exit with critical when nothing is passed and both critical and warning are passed' do
      check = CheckCertificateExpiry.new
      @aws_stub.stub_responses(:list_server_certificates, server_certificate_metadata_list: [@certificate_data[:server_certificate][:server_certificate_metadata]])
      allow(check).to receive(:aws_client).and_return(@aws_stub)
      allow(check).to receive(:check_expiry).and_return(['', true, true])

      # Make sure we are executing the correct block
      expect(check).to receive(:aws_client)
      response = check.run
      expect(response).to eq('triggered critical')
    end

    it 'should run and exit ok when name is passed' do
      check = CheckCertificateExpiry.new('-n my_test_cert'.split(' '))
      allow(check).to receive(:check_expiry).and_return(['', false, false])
      allow(check).to receive(:get_cert).and_return({})

      # Make sure we are executing the else block
      expect(check).to_not receive(:aws_client)
      response = check.run
      expect(response).to eq('triggered ok')
    end

    it 'should run and exit with warning when name is passed' do
      check = CheckCertificateExpiry.new('-n my_test_cert'.split(' '))
      allow(check).to receive(:check_expiry).and_return(['', true, false])
      allow(check).to receive(:get_cert).and_return({})

      # Make sure we are executing the else block
      expect(check).to_not receive(:aws_client)
      response = check.run
      expect(response).to eq('triggered warning')
    end

    it 'should run and exit with critical when name is passed' do
      check = CheckCertificateExpiry.new('-n my_test_cert'.split(' '))
      allow(check).to receive(:check_expiry).and_return(['', false, true])
      allow(check).to receive(:get_cert).and_return({})

      # Make sure we are executing the else block
      expect(check).to_not receive(:aws_client)
      response = check.run
      expect(response).to eq('triggered critical')
    end

    it 'should run and exit with critical when name is passed and both critical and warning are true' do
      check = CheckCertificateExpiry.new('-n my_test_cert'.split(' '))
      allow(check).to receive(:check_expiry).and_return(['', true, true])
      allow(check).to receive(:get_cert).and_return({})

      # Make sure we are executing the else block
      expect(check).to_not receive(:aws_client)
      response = check.run
      expect(response).to eq('triggered critical')
    end
  end
end
