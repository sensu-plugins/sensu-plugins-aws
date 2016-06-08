require 'aws-sdk'
require_relative '../../bin/check-kms-key.rb'
require_relative '../spec_helper.rb'

class CheckKMSKey
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

  def unknown(*)
    'triggered unknown'
  end
end

describe 'CheckKMSKey' do
  before :all do
    @aws_stub = Aws::KMS::Client.new(stub_responses: true, region: 'us-east-1')
    @valid_key = { key_metadata: { key_id: '1234', enabled: true } }
    @invalid_key = { key_metadata: { key_id: '1234', enabled: false } }
  end

  describe '#kms_client' do
    it 'should return a client' do
      check = CheckKMSKey.new
      expect(check.aws_config[:region]).to eq('us-east-1')
    end
  end

  describe '#get_key' do
    it 'should return true with valid enabled kms key' do
      check = CheckKMSKey.new
      @aws_stub.stub_responses(:describe_key, @valid_key)
      allow(check).to receive(:kms_client).and_return(@aws_stub)
      expect(true).to eq(check.check_key('id'))
    end

    it 'should return false with valid disabled kms key' do
      check = CheckKMSKey.new
      @aws_stub.stub_responses(:describe_key, @invalid_key)
      allow(check).to receive(:kms_client).and_return(@aws_stub)
      expect(false).to eq(check.check_key('id'))
    end

    it 'should return critical with invalid kms key' do
      check = CheckKMSKey.new
      allow(@aws_stub).to receive(:describe_key).and_raise(Aws::KMS::Errors::NotFoundException.new(nil, 'Error'))
      allow(check).to receive(:kms_client).and_return(@aws_stub)
      response = check.check_key('id')
      expect(response).to eq('triggered critical')
    end

    it 'should return unknown with random error' do
      check = CheckKMSKey.new
      allow(@aws_stub).to receive(:describe_key).and_raise(RuntimeError.new)
      allow(check).to receive(:kms_client).and_return(@aws_stub)
      response = check.check_key('id')
      expect(response).to eq('triggered unknown')
    end
  end

  describe '#run' do
    it 'should run and exit ok when enabled kms key is passed' do
      check = CheckKMSKey.new
      check.config[:key_id] = '1234'
      @aws_stub.stub_responses(:describe_key, @valid_key)
      allow(check).to receive(:kms_client).and_return(@aws_stub)
      response = check.run
      expect(response).to eq('triggered ok')
    end

    it 'should run and exit with warning when disabled kms key is passed' do
      check = CheckKMSKey.new
      check.config[:key_id] = '1234'
      @aws_stub.stub_responses(:describe_key, @invalid_key)
      allow(check).to receive(:kms_client).and_return(@aws_stub)
      response = check.run
      expect(response).to eq('triggered warning')
    end

    it 'should run and exit with unknown when nothing is passed' do
      check = CheckKMSKey.new
      response = check.run
      expect(response).to eq('triggered unknown')
    end
  end
end
