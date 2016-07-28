require 'aws-sdk'
require 'ostruct'
require_relative '../../bin/check-subnet-ip-consumption.rb'
require_relative '../spec_helper.rb'

class CheckSubnetIpConsumption
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

describe 'CheckSubnetIpConsumption' do
  before :all do
    @subnets = {
      subnets: [
        { subnet_id: 'subnet-test0123',
          state: 'available',
          cidr_block: '192.168.1.0/24',
          vpc_id: 'vpc-12345678',
          available_ip_address_count: 251,
          availability_zone: 'us-east-1a',
          tags: [{ key: 'Name', value: 'my_test_0123' }] }
      ]
    }
    @vpcs = {
      vpcs: [
        { vpc_id: 'vpc-12345678',
          state: 'available',
          cidr_block: '192.168.1.0/20',
          instance_tenancy: 'default',
          is_default: true,
          tags: [{ key: 'Name', value: 'my_vpc_12345678' }] }
      ]
    }
    Aws.config[:iam] = { stub_responses: {
      list_account_aliases: { account_aliases: ['my_account'] }
    } }
    Aws.config[:ec2] = { stub_responses: {
      describe_subnets: @subnets,
      describe_vpcs: @vpcs
    } }
  end
  let(:test_alert) do
    { subnet_id: 'subnet-00000000', subnet_name: 'subnet_name', subnet_consumed_pct: 60,
      subnet_vpc_id: 'vpc-00000000', subnet_consumed_capacity: 151, subnet_total_capacity: 251,
      subnet_az: 'us-east-1c', cidr_block: '192.168.99.0', vpc_friendly_name: 'vpc_name' }
  end
  let(:test_alert_with_no_names) do
    { subnet_id: 'subnet-00000000', subnet_name: '<no name>', subnet_consumed_pct: 60,
      subnet_vpc_id: 'vpc-00000000', subnet_consumed_capacity: 151, subnet_total_capacity: 251,
      subnet_az: 'us-east-1c', cidr_block: '192.168.99.0', vpc_friendly_name: '<no name>' }
  end

  describe '#ec2_client' do
    it 'a valid EC2 client exists' do
      check = CheckSubnetIpConsumption.new
      expect(check.ec2_client).to_not be_nil
    end
  end

  describe '#iam_client' do
    it 'a valid IAM client exists' do
      check = CheckSubnetIpConsumption.new
      expect(check.iam_client).to_not be_nil
    end
  end

  describe '#account_alias' do
    context 'with a valid account alias' do
      it 'returns nil when show_account_alias is false' do
        check = CheckSubnetIpConsumption.new
        expect(check.account_alias).to eq(nil)
      end
      it 'returns an account alias when show_account_alias is true' do
        check = CheckSubnetIpConsumption.new
        check.config[:show_account_alias] = true
        expect(check.account_alias).to eq('my_account')
      end
    end
    context 'with an empty account alias' do
      before :all do
        Aws.config[:iam] = { stub_responses: {
          list_account_aliases: { account_aliases: [''] }
        } }
      end
      it 'returns nil when show_account_alias is false' do
        check = CheckSubnetIpConsumption.new
        expect(check.account_alias).to eq(nil)
      end
      it 'returns \'<no alias>\' when show_account_alias is true and there is no name' do
        check = CheckSubnetIpConsumption.new
        check.config[:show_account_alias] = true
        expect(check.account_alias).to eq('<no alias>')
      end
    end
  end

  describe '#extract_name_tag' do
    let(:tags_empty) { [] }
    let(:tags_no_name) { [OpenStruct.new(key: 'Arbitrary', value: 'infinity')] }
    let(:tags_with_name) { [OpenStruct.new(key: 'Name', value: 'my_name')] }
    let(:tags_with_empty_name) { [OpenStruct.new(key: 'Name', value: '')] }

    context 'with no tags' do
      it 'returns <no name>' do
        check = CheckSubnetIpConsumption.new
        expect(check.extract_name_tag(tags_empty)).to eq('<no name>')
      end
    end
    context 'with tags' do
      context 'not including a Name tag' do
        it 'returns <no name>' do
          check = CheckSubnetIpConsumption.new
          expect(check.extract_name_tag(tags_no_name)).to eq('<no name>')
        end
      end
      context 'including an empty Name tag' do
        it 'returns <no name>' do
          check = CheckSubnetIpConsumption.new
          expect(check.extract_name_tag(tags_with_empty_name)).to eq('<no name>')
        end
      end
      context 'including a populated Name tag' do
        it 'returns the name' do
          check = CheckSubnetIpConsumption.new
          expect(check.extract_name_tag(tags_with_name)).to eq('my_name')
        end
      end
    end
  end

  describe '#display_subnet' do
    context 'with defaults' do
      it 'returns the subnet id' do
        check = CheckSubnetIpConsumption.new
        expect(check.display_subnet(test_alert)).to eq('subnet-00000000')
      end
    end
    context 'with show_friendly_names enabled' do
      it 'returns the subnet name' do
        check = CheckSubnetIpConsumption.new
        check.config[:show_friendly_names] = true
        expect(check.display_subnet(test_alert)).to eq('subnet_name')
      end
      context 'with a <no name> subnet' do
        it 'returns <no name>' do
          check = CheckSubnetIpConsumption.new
          check.config[:show_friendly_names] = true
          expect(check.display_subnet(test_alert_with_no_names)).to eq('<no name>')
        end
      end
    end
  end

  describe '#display_vpc' do
    context 'with defaults' do
      it 'returns the vpc id' do
        check = CheckSubnetIpConsumption.new
        expect(check.display_vpc(test_alert)).to eq('vpc-00000000')
      end
    end
    context 'with show_friendly_names enabled' do
      it 'returns the vpc name' do
        check = CheckSubnetIpConsumption.new
        check.config[:show_friendly_names] = true
        expect(check.display_vpc(test_alert)).to eq('vpc_name')
      end
      context 'with a <no name> vpc' do
        it 'returns <no name>' do
          check = CheckSubnetIpConsumption.new
          check.config[:show_friendly_names] = true
          expect(check.display_vpc(test_alert_with_no_names)).to eq('<no name>')
        end
      end
    end
  end

  describe '#run' do
    context 'with an empty subnet' do
      it 'should trigger ok with default threshold' do
        check = CheckSubnetIpConsumption.new
        response = check.run
        expect(response).to match('triggered ok')
      end
      it 'should trigger critical when threshold is lowered to 0' do
        check = CheckSubnetIpConsumption.new
        check.config[:alert_threshold] = 0
        response = check.run
        expect(response).to match('triggered critical')
      end
    end
    context 'with a full subnet' do
      before :all do
        @subnets = {
          subnets: [
            { subnet_id: 'subnet-test4567',
              state: 'available',
              cidr_block: '192.168.2.0/24',
              vpc_id: 'vpc-12345678',
              available_ip_address_count: 10,
              availability_zone: 'us-east-1b',
              tags: [{ key: 'Name', value: 'my_test_4567' }] }
          ]
        }
        @vpcs = {
          vpcs: [
            { vpc_id: 'vpc-12345678',
              state: 'available',
              cidr_block: '192.168.1.0/20',
              instance_tenancy: 'default',
              is_default: true,
              tags: [{ key: 'Name', value: 'my_vpc_12345678' }] }
          ]
        }

        Aws.config[:iam] = { stub_responses: {
          list_account_aliases: { account_aliases: ['my_account'] }
        } }
        Aws.config[:ec2] = { stub_responses: {
          describe_subnets: @subnets,
          describe_vpcs: @vpcs
        } }
      end
      it 'should trigger critical with default threshold' do
        check = CheckSubnetIpConsumption.new
        response = check.run
        expect(response).to match('triggered critical')
      end
      it 'should trigger ok when threshold is raised to 100' do
        check = CheckSubnetIpConsumption.new
        check.config[:alert_threshold] = 100
        response = check.run
        expect(response).to match('triggered ok')
      end
    end
  end
end
