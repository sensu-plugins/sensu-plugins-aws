require 'aws-sdk'
require_relative '../../bin/check-configservice-rules.rb'
require_relative '../spec_helper.rb'

class CheckConfigServiceRules
  at_exit do
    exit! 0
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

describe 'CheckConfigServiceRules' do
  before :all do
    @aws_stub = Aws::ConfigService::Client.new(stub_responses: true, region: 'us-east-1')

    @rule_data =
      {
        compliance_by_config_rules:  [
          {
            config_rule_name: 'Resources-Tagged',
            compliance: {
              compliance_type: 'NON_COMPLIANT',
              compliance_contributor_count: {
                capped_count: 25,
                cap_exceeded: true
              }
            }
          },
          {
            config_rule_name: 'Recent-Snapshots',
            compliance: {
              compliance_type: 'COMPLIANT',
              compliance_contributor_count: {
                capped_count: 25,
                cap_exceeded: true
              }
            }
          },
          {
            config_rule_name: 'Private-Subnet',
            compliance: {
              compliance_type: 'INSUFFICIENT_DATA',
              compliance_contributor_count: {
                capped_count: 25,
                cap_exceeded: true
              }
            }
          }
        ]
      }
  end

  describe '#aws_client' do
    it 'should return a client' do
      check = CheckConfigServiceRules.new
      options = { stub_responses: true }
      client = check.aws_client(options)
      expect(client.config.stub_responses).to eq(true)
      expect(client.config.region).to eq('us-east-1')
    end

    it 'should return a client with west region' do
      check = CheckConfigServiceRules.new
      options = { stub_responses: true, region: 'us-west-2' }
      client = check.aws_client(options)
      expect(client.config.stub_responses).to eq(true)
      expect(client.config.region).to eq('us-west-2')
    end
  end

  describe '#get_config_rules_data' do
    it 'should return compliance data' do
      check = CheckConfigServiceRules.new
      @aws_stub.stub_responses(:describe_compliance_by_config_rule, @rule_data)
      allow(check).to receive(:aws_client).and_return(@aws_stub)
      rules = check.get_config_rules_data
      expect(rules.select { |r| r.config_rule_name == 'Private-Subnet' }[0].compliance.compliance_type).to eq('INSUFFICIENT_DATA')
    end
  end

  describe '#get_rule_names_by_compliance_type' do
    it 'should return a non-compliant rule' do
      check = CheckConfigServiceRules.new
      @aws_stub.stub_responses(:describe_compliance_by_config_rule, @rule_data)
      allow(check).to receive(:aws_client).and_return(@aws_stub)
      rules = check.get_config_rules_data

      expect(check.get_rule_names_by_compliance_type(rules, 'NON_COMPLIANT')).to eq(['Resources-Tagged'])
    end
  end

  describe '#run' do
    it 'should run and exit critical when passed nothing' do
      check = CheckConfigServiceRules.new
      @aws_stub.stub_responses(:describe_compliance_by_config_rule, @rule_data)
      allow(check).to receive(:aws_client).and_return(@aws_stub)
      response = check.run

      # the stubbed data includes a non-compliant rule, so we should CRIT
      expect(response).to eq('triggered critical')
    end
  end
end
