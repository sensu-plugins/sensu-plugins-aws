require 'aws-sdk'
require_relative '../../bin/check-target-group-instance-count.rb'
require_relative '../spec_helper.rb'

class CheckTargetGroupInstanceCount
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

describe 'CheckTargetGroupInstanceCount' do
  before :all do
    @aws_stub = Aws::ElasticLoadBalancingV2::Client.new(stub_responses: true, region: 'us-east-1')
    @aws_stub.stub_responses(:describe_target_groups, target_groups: [{ target_group_name: 'test', target_group_arn: 'arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/test/73e2d6bc24d8a067' }])
  end

  describe '#target_group' do
    it 'should return a critical with an empty target group' do
      check = CheckTargetGroupInstanceCount.new
      check.config[:target_group] = 'test'
      allow(check).to receive(:alb).and_return(@aws_stub)

      expect(check.run).to eq('triggered critical')
    end

    it 'should return a critical when lower than default threshold' do
      check = CheckTargetGroupInstanceCount.new
      check.config[:target_group] = 'test'
      @aws_stub.stub_responses(:describe_target_health, target_health_descriptions: [{ health_check_port: '80' }])
      allow(check).to receive(:alb).and_return(@aws_stub)

      expect(check.run).to eq('triggered critical')
    end

    it 'should return a warning when lower than default threshold' do
      check = CheckTargetGroupInstanceCount.new
      check.config[:target_group] = 'test'
      @aws_stub.stub_responses(:describe_target_health, target_health_descriptions: [{ health_check_port: '80' }, { health_check_port: '80' }])
      allow(check).to receive(:alb).and_return(@aws_stub)

      expect(check.run).to eq('triggered warning')
    end

    it 'should return a ok when higher than default thresholds' do
      check = CheckTargetGroupInstanceCount.new
      check.config[:target_group] = 'test'
      @aws_stub.stub_responses(:describe_target_health, target_health_descriptions: [{ health_check_port: '80' }, { health_check_port: '80' }, { health_check_port: '80' }, { health_check_port: '80' }])
      allow(check).to receive(:alb).and_return(@aws_stub)

      expect(check.run).to eq('triggered ok')
    end

    it 'should return a critical when lower than set threshold' do
      check = CheckTargetGroupInstanceCount.new
      check.config[:target_group] = 'test'
      check.config[:crit_count] = 2
      @aws_stub.stub_responses(:describe_target_health, target_health_descriptions: [{ health_check_port: '80' }, { health_check_port: '80' }])
      allow(check).to receive(:alb).and_return(@aws_stub)

      expect(check.run).to eq('triggered critical')
    end

    it 'should return a warning when lower than set threshold' do
      check = CheckTargetGroupInstanceCount.new
      check.config[:target_group] = 'test'
      check.config[:warn_count] = 5
      @aws_stub.stub_responses(:describe_target_health, target_health_descriptions: [{ health_check_port: '80' }, { health_check_port: '80' }, { health_check_port: '80' }, { health_check_port: '80' }])
      allow(check).to receive(:alb).and_return(@aws_stub)

      expect(check.run).to eq('triggered warning')
    end

    it 'should return a ok when higher than set thresholds' do
      check = CheckTargetGroupInstanceCount.new
      check.config[:target_group] = 'test'
      check.config[:warn_count] = 3
      check.config[:warn_count] = 2
      @aws_stub.stub_responses(:describe_target_health, target_health_descriptions: [{ health_check_port: '80' }, { health_check_port: '80' }, { health_check_port: '80' }, { health_check_port: '80' }])
      allow(check).to receive(:alb).and_return(@aws_stub)

      expect(check.run).to eq('triggered ok')
    end

    it 'should return a warning when lower than set warning threshold but higher than critical one' do
      check = CheckTargetGroupInstanceCount.new
      check.config[:target_group] = 'test'
      check.config[:crit_count] = 2
      check.config[:warn_count] = 5
      @aws_stub.stub_responses(:describe_target_health, target_health_descriptions: [{ health_check_port: '80' }, { health_check_port: '80' }, { health_check_port: '80' }, { health_check_port: '80' }])
      allow(check).to receive(:alb).and_return(@aws_stub)

      expect(check.run).to eq('triggered warning')
    end
  end
end
