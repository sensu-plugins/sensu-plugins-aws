require 'aws-sdk'

module CloudwatchCommon
  def client
    Aws::CloudWatch::Client.new
  end

  def read_value(resp, stats)
    resp.datapoints.first.send(stats.downcase)
  end

  def resp_has_no_data(resp, stats)
    resp.datapoints.nil? || resp.datapoints.length == 0 || resp.datapoints.first.nil? || read_value(resp, stats).nil?
  end

  def compare(value, threshold, compare_method)
    if compare_method == 'greater'
      return value > threshold
    elsif compare_method == 'less'
      return value < threshold
    elsif compare_method == 'not'
      return value != threshold
    else
      return value == threshold
    end
  end

  def metrics_request(config)
    {
      namespace: config[:namespace],
      metric_name: config[:metric_name],
      dimensions: config[:dimensions],
<<<<<<< HEAD
      start_time: Time.now - config[:period]*10,
=======
      start_time: Time.now - config[:period] * 10,
>>>>>>> 539aec13b0d9001c92a4fbfdcd21a98de53efa89
      end_time: Time.now,
      period: config[:period],
      statistics: [config[:statistics]],
      unit: config[:unit]
    }
  end

  def check(config)
    resp = client.get_metric_statistics(metrics_request(config))

    no_data = resp_has_no_data(resp, config[:statistics])
<<<<<<< HEAD
    if no_data and config[:no_data_ok]
      ok "#{metric_desc} returned no data but that's ok"
    elsif no_data and not config[:no_data_ok]
=======
    if no_data && config[:no_data_ok]
      ok "#{metric_desc} returned no data but that's ok"
    elsif no_data && !config[:no_data_ok]
>>>>>>> 539aec13b0d9001c92a4fbfdcd21a98de53efa89
      unknown "#{metric_desc} could not be retrieved"
    end

    value = read_value(resp, config[:statistics])
    base_msg = "#{metric_desc} is #{value}: comparison=#{config[:compare]}"

<<<<<<< HEAD
    if compare value, config[:critical], config[:comparison]
      critical "#{base_msg} threshold=#{config[:critical]}"
    elsif config[:warning] and compare value, config[:warning], config[:comparison]
      warning "#{base_msg} threshold=#{config[:warning]}"
    else
      ok "#{base_msg}, will alarm at #{config[:warning] != nil ? config[:warning] : config[:critical]}"
=======
    if compare value, config[:critical], config[:compare]
      critical "#{base_msg} threshold=#{config[:critical]}"
    elsif config[:warning] && compare(value, config[:warning], config[:compare])
      warning "#{base_msg} threshold=#{config[:warning]}"
    else
      ok "#{base_msg}, will alarm at #{!config[:warning].nil? ? config[:warning] : config[:critical]}"
>>>>>>> 539aec13b0d9001c92a4fbfdcd21a98de53efa89
    end
  end
end
