require 'aws-sdk'
require_relative '../../bin/check-s3-bucket-visibility.rb'
require_relative '../spec_helper.rb'

class CheckS3Bucket
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

describe 'CheckS3Bucket' do
  get_policy = {
    'Version' => '2012-10-17',
    'Statement' => [
      {
        'Sid' => 'AddPerm',
        'Effect' => 'Allow',
        'Principal' => '*',
        'Action' => ['s3:GetObject'],
        'Resource' => ['arn:aws:s3:::examplebucket/*']
      }
    ]
  }

  before :all do
    @aws_stub = Aws::S3::Client.new(stub_responses: true)
    @website_policy = {}
    @valid_key = { key_metadata: { key_id: '1234', enabled: true } }
    @invalid_key = { key_metadata: { key_id: '1234', enabled: false } }
  end

  describe '#website_configuration?' do
    it 'returns true when a website config is found' do
      check = CheckS3Bucket.new
      @aws_stub.stub_responses(:get_bucket_website, @website_policy)
      allow(check).to receive(:s3_client).and_return(@aws_stub)
      expect(true).to eq(check.website_configuration?('bucket_with_config'))
    end

    it 'returns false when no website config exists' do
      check = CheckS3Bucket.new
      @aws_stub.stub_responses(:get_bucket_website, 'NoSuchWebsiteConfiguration')
      allow(check).to receive(:s3_client).and_return(@aws_stub)
      expect(false).to eq(check.website_configuration?('bucket_without_config'))
    end
  end

  describe 'policy_too_permissive?' do
    it 'returns true when a policy statement includes s3:Get' do
      check = CheckS3Bucket.new
      expect(true).to eq(check.policy_too_permissive?(get_policy))
    end
  end

  describe '#run' do
    it 'exits ok when restricted and no website policy' do
      check = CheckS3Bucket.new
      check.config[:bucket_names] = ['my_bucket']
      check.config[:exclude_buckets] = ['some_other_bucket']
      @aws_stub.stub_responses(:get_bucket_website, 'NoSuchWebsiteConfiguration')
      @aws_stub.stub_responses(:get_bucket_policy, 'NoSuchBucketPolicy')
      allow(check).to receive(:s3_client).and_return(@aws_stub)
      response = check.run
      expect(response).to eq('triggered ok')
    end

    it 'exits with critical when a website policy is detected' do
      check = CheckS3Bucket.new
      check.config[:bucket_names] = ['my_bucket']
      check.config[:exclude_buckets] = ['some_other_bucket']
      @aws_stub.stub_responses(:get_bucket_website, @website_policy)
      @aws_stub.stub_responses(:get_bucket_policy, 'NoSuchBucketPolicy')
      allow(check).to receive(:s3_client).and_return(@aws_stub)
      response = check.run
      expect(response).to eq('triggered critical')
    end

    it 'exits with critical when an overly permissive policy is detected' do
      skip "Can't mock StringIO in :get_bucket_policy"
      check = CheckS3Bucket.new
      check.config[:bucket_names] = ['my_bucket']
      check.config[:exclude_buckets] = ['some_other_bucket']
      @aws_stub.stub_responses(:get_bucket_website, 'NoSuchWebsiteConfiguration')
      @aws_stub.stub_responses(:get_bucket_policy, policy: '{}')
      allow(check).to receive(:s3_client).and_return(@aws_stub)
      response = check.run
      expect(response).to eq('triggered critical')
    end

    it 'exits with critical when one of two buckets fail' do
      check = CheckS3Bucket.new
      check.config[:bucket_names] = %w[safe_bucket fail_bucket]
      check.config[:exclude_buckets] = ['some_other_bucket']
      @aws_stub.stub_responses(:get_bucket_website, ['NoSuchWebsiteConfiguration', @website_policy])
      allow(check).to receive(:s3_client).and_return(@aws_stub)
      response = check.run
      expect(response).to eq('triggered critical')
    end

    it 'exits with warning on a missing bucket' do
      check = CheckS3Bucket.new
      check.config[:bucket_names] = ['missing_bucket']
      check.config[:exclude_buckets] = ['some_other_bucket']
      check.config[:critical_on_missing] = 'false'
      @aws_stub.stub_responses(:get_bucket_website, 'NoSuchBucket')
      @aws_stub.stub_responses(:get_bucket_policy, 'NoSuchBucketPolicy')
      allow(check).to receive(:s3_client).and_return(@aws_stub)
      response = check.run
      expect(response).to eq('triggered warning')
    end

    it 'exits with critical on a missing bucket when -m is specified' do
      check = CheckS3Bucket.new
      check.config[:bucket_names] = ['missing_bucket']
      check.config[:exclude_buckets] = ['some_other_bucket']
      check.config[:critical_on_missing] = 'true'
      @aws_stub.stub_responses(:get_bucket_website, 'NoSuchBucket')
      allow(check).to receive(:s3_client).and_return(@aws_stub)
      response = check.run
      expect(response).to eq('triggered critical')
    end

    it 'exists with critical when one of several buckets is missing when -m is specified' do
      check = CheckS3Bucket.new
      check.config[:bucket_names] = %w[actual_bucket missing_bucket]
      check.config[:exclude_buckets] = []
      check.config[:critical_on_missing] = 'true'
      @aws_stub.stub_responses(:get_bucket_website, %w[NoSuchWebsiteConfiguration NoSuchBucket])
      @aws_stub.stub_responses(:get_bucket_policy, %w[NoSuchBucketPolicy NoSuchBucket])
      allow(check).to receive(:s3_client).and_return(@aws_stub)
      response = check.run
      expect(response).to eq('triggered critical')
    end
  end
end
