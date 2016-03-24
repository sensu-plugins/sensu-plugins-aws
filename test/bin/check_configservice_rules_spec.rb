require 'aws-sdk'
require_relative '../spec_helper.rb'
require_relative '../../bin/check-configservice-rules.rb'

describe 'CheckConfigServiceRules' do
  before :all do
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

    Aws.config[:configservice] = {
      stub_responses: {
        describe_compliance_by_config_rule: @rule_data
      }
    }
  end

  describe '#get_config_rules_data' do
    it 'should return compliance data' do
      check = CheckConfigServiceRules.new
      rules = check.get_config_rules_data

      expect(rules.select { |r| r.config_rule_name == 'Private-Subnet' }[0].compliance.compliance_type).to eq('INSUFFICIENT_DATA')
    end
  end

  describe '#get_rule_names_by_compliance_type' do
    it 'should return a non-compliant rule' do
      check = CheckConfigServiceRules.new
      rules = check.get_config_rules_data

      expect(check.get_rule_names_by_compliance_type(rules, 'NON_COMPLIANT')).to eq(['Resources-Tagged'])
    end
  end

  describe '#run' do
    it 'should run and exit critical when passed nothing' do
      check = CheckConfigServiceRules.new
      response = check.run

      # the stubbed data includes a non-compliant rule, so we should CRIT
      expect(response).to match(/triggered critical(.*)Resources-Tagged/)
    end
  end
end
