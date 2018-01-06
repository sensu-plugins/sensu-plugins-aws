require_relative '../spec_helper.rb'
require_relative '../../bin/check-ecs-service-health.rb'
require_relative '../ecs_stubs.rb'

describe 'CheckEcsServiceHealth' do
  after :all do
    Aws.config = {}
  end
  describe 'with full stub' do
    before :all do
      # Default stub contains a service in every possible state
      stub_default
    end

    describe '#service_list' do
      it 'should return all services by default' do
        check = CheckEcsServiceHealth.new
        services = check.service_list

        expect(services).to eq(ALL_SERVICES.map { |s| s[:service_arn] })
      end

      it 'should return only services specified' do
        check = CheckEcsServiceHealth.new

        services = check.service_list(nil, 'my-broken-ecs-service')
        expect(services).to eq(['my-broken-ecs-service'])
      end
    end

    describe '#service_details' do
      it 'should fetch details for all services by default' do
        check = CheckEcsServiceHealth.new
        services = check.service_details

        expect(services.collect(&:service_arn)).to eq(ALL_SERVICES.map { |s| s[:service_arn] })
      end
    end

    describe '#services_by_health' do
      it 'should consider a service critical when none running but non-zero required' do
        check = CheckEcsServiceHealth.new
        services = check.services_by_health

        expect(services[:critical].collect(&:service_name)).to eq([CRIT_SERVICE[:service_name]])
      end

      it 'should consider a service warning when 0 < running < desired' do
        check = CheckEcsServiceHealth.new
        services = check.services_by_health

        expect(services[:warn].collect(&:service_name)).to eq([WARN_SERVICE[:service_name]])
      end

      it 'should consider a service okay when running >= desired' do
        check = CheckEcsServiceHealth.new
        services = check.services_by_health

        expect(services[:ok].collect(&:service_name)).to eq([OK_SERVICE[:service_name], DISABLED_SERVICE[:service_name], DEPLOYING_SERVICE[:service_name]])
      end
    end

    describe '#run' do
      it 'should run and exit critical' do
        check = CheckEcsServiceHealth.new
        response = check.run

        # The stubbed data includes a broken service, so we should CRIT
        expect(response).to match(/^triggered critical(.*)my-broken-ecs-service(.*)$/)
      end
    end
  end

  describe 'with warning stub' do
    before :all do
      # Contains a service where 0 < desired < running
      stub_warn
    end

    describe '#run' do
      it 'should run and exit warn by default' do
        check = CheckEcsServiceHealth.new
        response = check.run

        # The stubbed data includes a broken service, so we should WARN
        expect(response).to match(/^triggered warning(.*)#{WARN_SERVICE[:service_name]}(.*)$/)
      end

      it 'should run and exit crit when warn_as_crit = true' do
        check = CheckEcsServiceHealth.new
        allow(check).to receive(:config).and_return(warn_as_crit: true)
        response = check.run

        # We should treat the warning service as critical due to config
        expect(response).to match(/^triggered critical(.*)#{WARN_SERVICE[:service_name]}(.*)$/)
      end
    end
  end

  describe 'with ok stub' do
    before :all do
      # Contains two healthy services
      stub_ok
    end

    describe '#run' do
      it 'should run and exit ok' do
        check = CheckEcsServiceHealth.new
        response = check.run

        expect(response).to match(/^triggered ok(.*)$/)
      end
    end
  end
end
