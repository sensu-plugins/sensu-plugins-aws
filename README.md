## Sensu-Plugins-aws

[![Build Status](https://travis-ci.org/sensu-plugins/sensu-plugins-aws.svg?branch=master)](https://travis-ci.org/sensu-plugins/sensu-plugins-aws)
[![Gem Version](https://badge.fury.io/rb/sensu-plugins-aws.svg)](http://badge.fury.io/rb/sensu-plugins-aws)
[![Code Climate](https://codeclimate.com/github/sensu-plugins/sensu-plugins-aws/badges/gpa.svg)](https://codeclimate.com/github/sensu-plugins/sensu-plugins-aws)
[![Test Coverage](https://codeclimate.com/github/sensu-plugins/sensu-plugins-aws/badges/coverage.svg)](https://codeclimate.com/github/sensu-plugins/sensu-plugins-aws)

## Functionality

**autoscaling-instance-count-metrics.rb**
**check-dynamodb-capacity.rb**
**check-dynamodb-throttle.rb**
**check-ec2-network.rb**
**check-elb-certs.rb**
**check-elb-health-fog.rb**
**check-elb-health.rb**
**check-elb-latency.rb**
**check-elb-nodes.rb**
**check-elb-sum-requests.rb**
**check-instance-events.rb**
**check-rds-events.rb**
**check-rds.rb**
**check-redshift-events.rb**
**check-ses-limit.rb**
**check-sqs-messages.rb**
**ec2-count-metrics.rb**
**ec2-node.rb**
**elasticache-metrics.rb**
**elb-full-metrics.rb**
**elb-latency-metrics.rb**
**elb-metrics.rb**
**sqs-metrics.rb**

## Files

* /bin/autoscaling-instance-count-metrics.rb
* /bin/check-dynamodb-capacity.rb
* /bin/check-dynamodb-throttle.rb
* /bin/check-ec2-network.rb
* /bin/check-elb-certs.rb
* /bin/check-elb-health-fog.rb
* /bin/check-elb-health.rb
* /bin/check-elb-latency.rb
* /bin/check-elb-nodes.rb
* /bin/check-elb-sum-requests.rb
* /bin/check-instance-events.rb
* /bin/check-rds-events.rb
* /bin/check-rds.rb
* /bin/check-redshift-events.rb
* /bin/check-ses-limit.rb
* /bin/check-sqs-messages.rb
* /bin/ec2-count-metrics.rb
* /bin/ec2-node.rb
* /bin/elasticache-metrics.rb
* /bin/elb-full-metrics.rb
* /bin/elb-latency-metrics.rb
* /bin/elb-metrics.rb
* /bin/sqs-metrics.rb

## Usage

## Installation

Add the public key (if you haven’t already) as a trusted certificate

```
gem cert --add <(curl -Ls https://raw.githubusercontent.com/sensu-plugins/sensu-plugins.github.io/master/certs/sensu-plugins.pem)
gem install <gem> -P MediumSecurity
```

You can also download the key from /certs/ within each repository.

`gem install sensu-plugins-aws`

Add *sensu-plugins-aws* to your Gemfile, manifest, cookbook, etc

## Notes
