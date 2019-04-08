module CloudwatchCommon
  include Common

  def client
    @client ||= Aws::CloudWatch::Client.new
  end

  def read_value(resp, stats)
    if extended_stats? stats
      resp.datapoints.sort_by(&:timestamp).last.extended_statistics[stats]
    else
      resp.datapoints.sort_by(&:timestamp).last.send(stats.downcase)
    end
  end

  def resp_has_no_data(resp, stats)
    resp.datapoints.nil? || resp.datapoints.empty? || resp.datapoints.first.nil? || read_value(resp, stats).nil?
  end

  def compare(value, threshold, compare_method)
    case compare_method
    when 'greater'
      value > threshold
    when 'less'
      value < threshold
    when 'not'
      value != threshold
    else
      value == threshold
    end
  end

  def extended_stats?(stats)
    stats[/p\d+\.\d+|p\d+/] # Check for percentile format
  end

  def metrics_request(config)
    request = {
      namespace: config[:namespace],
      metric_name: config[:metric_name],
      dimensions: config[:dimensions],
      start_time: Time.now - config[:period] * 10,
      end_time: Time.now,
      period: config[:period],
      unit: config[:unit]
    }
    stats_key = extended_stats?(config[:statistics]) ? :extended_statistics : :statistics
    request[stats_key] = [config[:statistics]]
    request
  end

  def get_metric(metric)
    client.get_metric_statistics(composite_metrics_request(metric))
  end

  def composite_metrics_request(metric)
    ## config is a class variable but don't want to change signature
    metrics_request(config).merge(metric_name: metric)
  end

  def self.parse_dimensions(dimension_string)
    dimension_string.split(',')
                    .collect { |d| d.split '=' }
                    .collect { |a| { name: a[0], value: a[1] } }
  end

  def dimension_string
    config[:dimensions].map { |d| "#{d[:name]}=#{d[:value]}" }.join('&')
  end

  def check(config)
    resp = client.get_metric_statistics(metrics_request(config))

    no_data = resp_has_no_data(resp, config[:statistics])
    if no_data && config[:no_data_ok]
      ok "#{metric_desc} returned no data but that's ok"
    elsif no_data && !config[:no_data_ok]
      unknown "#{metric_desc} could not be retrieved"
    end

    value = read_value(resp, config[:statistics])
    base_msg = "#{metric_desc} is #{value}: comparison=#{config[:compare]}"

    if compare value, config[:critical], config[:compare]
      critical "#{base_msg} threshold=#{config[:critical]}"
    elsif config[:warning] && compare(value, config[:warning], config[:compare])
      warning "#{base_msg} threshold=#{config[:warning]}"
    else
      ok "#{base_msg}, will alarm at #{!config[:warning].nil? ? config[:warning] : config[:critical]}"
    end
  end
end
