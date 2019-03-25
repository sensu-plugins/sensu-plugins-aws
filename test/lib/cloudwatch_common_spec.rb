require 'aws-sdk'

class DummyCheck < Sensu::Plugin::Check::CLI
  at_exit do
    @@autorun = false
  end

  include CloudwatchCommon
end

describe 'CloudwatchCommon' do
  before :all do
    @check = DummyCheck.new
  end

  describe '#client' do
    it 'should return a cloudwatch client' do
      expect(@check.client).to be_instance_of(Aws::CloudWatch::Client)
    end

    it 'should memoize and return same client on subsequent calls' do
      client = @check.client
      expect(@check.client).to be(client)
    end
  end

  describe '#read_value' do
    it 'should return the last datapoint' do
      client = Aws::CloudWatch::Client.new
      resp = client.stub_data(:get_metric_statistics, datapoints: [{ timestamp: Time.new(2000), average: 0.to_f }, { timestamp: Time.new(2010), average: 1.to_f }])
      value = @check.read_value(resp, 'average')
      expect(value).to equal(1.to_f)
    end

    it 'should sort by timestamp' do
      client = Aws::CloudWatch::Client.new
      resp = client.stub_data(:get_metric_statistics, datapoints: [{ timestamp: Time.new(2010), average: 1.to_f }, { timestamp: Time.new(2000), average: 0.to_f }])
      value = @check.read_value(resp, 'average')
      expect(value).to equal(1.to_f)
    end
  end

  describe '#resp_has_no_data' do
    it 'should return true if datapoints is nil' do
      client = Aws::CloudWatch::Client.new
      resp = client.stub_data(:get_metric_statistics)
      value = @check.resp_has_no_data(resp, 'average')
      expect(value).to be(true)
    end

    it 'should return true if datapoints is empty' do
      client = Aws::CloudWatch::Client.new
      resp = client.stub_data(:get_metric_statistics, datapoints: [])
      value = @check.resp_has_no_data(resp, 'average')
      expect(value).to be(true)
    end

    it 'should return true if the first datapoint is nil' do
      client = Aws::CloudWatch::Client.new
      resp = client.stub_data(:get_metric_statistics, datapoints: [{}])
      value = @check.resp_has_no_data(resp, 'average')
      expect(value).to be(true)
    end

    it 'should return true if the value is nil' do
      client = Aws::CloudWatch::Client.new
      resp = client.stub_data(:get_metric_statistics, datapoints: [{ timestamp: Time.new(2010), average: nil }])
      value = @check.resp_has_no_data(resp, 'average')
      expect(value).to be(true)
    end

    it 'should return false if valid data is present' do
      client = Aws::CloudWatch::Client.new
      resp = client.stub_data(:get_metric_statistics, datapoints: [{ timestamp: Time.new(2010), average: 1.to_f }, { timestamp: Time.new(2000), average: 0.to_f }])
      value = @check.resp_has_no_data(resp, 'average')
      expect(value).to equal(false)
    end
  end

  describe '#compare' do
    describe 'compare_method is less' do
      it 'should return true' do
        compare_method = 'less'
        result = @check.compare(1, 10, compare_method)
        expect(result).to be(true)
      end

      it 'should return false' do
        compare_method = 'less'
        result = @check.compare(10, 1, compare_method)
        expect(result).to be(false)
      end
    end

    describe 'compare_method is greater' do
      it 'should return false' do
        compare_method = 'greater'
        result = @check.compare(1, 10, compare_method)
        expect(result).to be(false)
      end

      it 'should return true' do
        compare_method = 'greater'
        result = @check.compare(10, 1, compare_method)
        expect(result).to be(true)
      end
    end

    describe 'compare_method is not' do
      it 'should return false' do
        compare_method = 'not'
        result = @check.compare(10, 10, compare_method)
        expect(result).to be(false)
      end

      it 'should return true' do
        compare_method = 'not'
        result = @check.compare(1, 10, compare_method)
        expect(result).to be(true)
      end
    end

    describe 'compare_method is equal' do
      it 'should return false' do
        compare_method = 'equal'
        result = @check.compare(1, 10, compare_method)
        expect(result).to be(false)
      end

      it 'should return true' do
        compare_method = 'equal'
        result = @check.compare(10, 10, compare_method)
        expect(result).to be(true)
      end
    end

    describe 'compare_method is foo' do
      it 'should return false' do
        compare_method = 'foo'
        result = @check.compare(1, 10, compare_method)
        expect(result).to be(false)
      end

      it 'should return true' do
        compare_method = 'foo'
        result = @check.compare(10, 10, compare_method)
        expect(result).to be(true)
      end
    end
  end

  describe '#metrics_reuquest' do
    it 'should return the proper payload' do
      config = {
        namespace: 'namespace',
        metric_name: 'metric_name',
        dimensions: 'dimensions',
        period: 2,
        statistics: 'stats',
        unit: 'foo'
      }
      resp = @check.metrics_request(config)
      expect(resp[:namespace]).to be(config[:namespace])
      expect(resp[:metric_name]).to be(config[:metric_name])
      expect(resp[:dimensions]).to be(config[:dimensions])
      expect(resp[:period]).to be(config[:period])
      expect(resp[:statistics]).to eq([config[:statistics]])
      expect(resp[:unit]).to be(config[:unit])
      expect((resp[:end_time] - resp[:start_time]).to_i).to be(config[:period] * 10)
    end

    it 'should return the proper payload with extended_statistics' do
      config = {
        namespace: 'namespace',
        metric_name: 'metric_name',
        dimensions: 'dimensions',
        period: 2,
        statistics: 'p90',
        unit: 'foo'
      }
      resp = @check.metrics_request(config)
      expect(resp[:namespace]).to be(config[:namespace])
      expect(resp[:metric_name]).to be(config[:metric_name])
      expect(resp[:dimensions]).to be(config[:dimensions])
      expect(resp[:period]).to be(config[:period])
      expect(resp[:extended_statistics]).to eq([config[:statistics]])
      expect(resp[:unit]).to be(config[:unit])
      expect((resp[:end_time] - resp[:start_time]).to_i).to be(config[:period] * 10)
    end

    it 'should return the proper payload with extended_statistics' do
      config = {
        namespace: 'namespace',
        metric_name: 'metric_name',
        dimensions: 'dimensions',
        period: 2,
        statistics: 'p90.50',
        unit: 'foo'
      }
      resp = @check.metrics_request(config)
      expect(resp[:namespace]).to be(config[:namespace])
      expect(resp[:metric_name]).to be(config[:metric_name])
      expect(resp[:dimensions]).to be(config[:dimensions])
      expect(resp[:period]).to be(config[:period])
      expect(resp[:extended_statistics]).to eq([config[:statistics]])
      expect(resp[:unit]).to be(config[:unit])
      expect((resp[:end_time] - resp[:start_time]).to_i).to be(config[:period] * 10)
    end
  end

  describe '#composite_metrics_request' do
    it 'should return the proper payload' do
      config = {
        namespace: 'namespace',
        dimensions: 'dimensions',
        period: 2,
        statistics: 'stats',
        unit: 'foo'
      }
      @check.config = config
      m = 'metric'
      resp = @check.composite_metrics_request(m)
      expect(resp[:namespace]).to be(config[:namespace])
      expect(resp[:metric_name]).to be(m)
      expect(resp[:dimensions]).to be(config[:dimensions])
      expect(resp[:period]).to be(config[:period])
      expect(resp[:statistics]).to eq([config[:statistics]])
      expect(resp[:unit]).to be(config[:unit])
      expect((resp[:end_time] - resp[:start_time]).to_i).to be(config[:period] * 10)
    end
  end
end
