## Sensu-Plugins-aws

[![Build Status](https://travis-ci.org/sensu-plugins/sensu-plugins-aws.svg?branch=master)](https://travis-ci.org/sensu-plugins/sensu-plugins-aws)
[![Gem Version](https://badge.fury.io/rb/sensu-plugins-aws.svg)](https://badge.fury.io/rb/sensu-plugins-aws.svg)
[![Sensu Bonsai Asset](https://img.shields.io/badge/Bonsai-Download%20Me-brightgreen.svg?colorB=89C967&logo=sensu)](https://bonsai.sensu.io/assets/sensu-plugins/sensu-plugins-aws)

## Sensu Asset
The Sensu assets packaged from this repository are built against the Sensu Ruby runtime environment. When using these assets as part of a Sensu Go resource (check, mutator or handler), make sure you include the corresponding Sensu Ruby runtime asset in the list of assets needed by the resource. The current ruby-runtime assets can be found [here](https://bonsai.sensu.io/assets/sensu/sensu-ruby-runtime) in the [Bonsai Asset Index](bonsai.sensu.io).

## Functionality

**check-alb-target-group-health.rb**

**check-asg-instances-created.rb**

**check-asg-instances-inservice.rb**

**check-autoscaling-cpucredits.rb**

**check-beanstalk-elb-metric.rb**

**check-certificate-expiry.rb**

**check-cloudwatch-alarm**

**check-cloudwatch-alarms**

**check-cloudwatch-composite-metric**

**check-cloudwatch-metric**

**check-cloudfront-tag**

**check-configservice-rules**

**check-dynamodb-capacity.rb**

**check-dynamodb-throttle.rb**

**check-direct-connect-virtual-interfaces.rb**

**check-ebs-snapshots.rb**

**check-ebs-burst-limit.rb**

**check-ec2-cpu_balance.rb**

**check-ec2-filter.rb**

**check-ec2-network.rb**

**check-ecs-service-health.rb**

**check-efs-metric.rb**

**check-eip-allocation.rb**

**check-elasticache-failover.rb**

**check-elb-certs.rb**

**check-elb-health-fog.rb**

**check-elb-health-sdk.rb**

**check-elb-health.rb**

**check-elb-instances-inservice.rb**

**check-elb-latency.rb**

**check-elb-nodes.rb**

**check-elb-sum-requests.rb**

**check-emr-cluster.rb**

**check-emr-steps.rb**

**check-eni-status.rb**

**check-instance-events.rb**

**check-instance-health.rb**

**check-kms-key.rb**

**check-rds-events.rb**

**check-rds-pending.rb**

**check-rds.rb**

**check-redshift-events.rb**

**check-reserved-instances.rb**

**check-route53-domain-expiration.rb**

**check-s3-bucket.rb**

**check-s3-bucket-visibility.rb**

**check-s3-object.rb**

**check-s3-tag.rb**

**check-ses-limit.rb**

**check-ses-statistics.rb**

**check-sns-subscriptions**

**check-sqs-messages.rb**

**check-subnet-ip-consumption**

**check-vpc-nameservers**

**check-instances-count.rb**

**check-vpc-vpn.rb**

**handler-ec2_node.rb**

**handler-scale-asg-down.rb**

**handler-scale-asg-up.rb**

**handler-ses.rb**

**handler-sns.rb**

**metrics-asg.rb**

**metrics-autoscaling-instance-count.rb**

**metrics-billing.rb**

**metrics-ec2-count.rb**

**metrics-ec2-filter.rb**

**metrics-elasticache.rb**

**metrics-elb-full.rb**

**metrics-elb.rb**

**metrics-emr-steps.rb**

**metrics-rds.rb**

**metrics-s3.rb**

**metrics-ses.rb**

**metrics-sqs.rb**


## Files

* /bin/check-alb-target-group-health.rb
* /bin/check-asg-instances-created.rb
* /bin/check-autoscaling-cpucredits.rb
* /bin/check-asg-instances-inservice.rb
* /bin/check-beanstalk-elb-metric.rb
* /bin/check-certificate-expiry.rb
* /bin/check-configservice-rules.rb
* /bin/check-cloudfront-tag.rb
* /bin/check-cloudwatch-alarm.rb
* /bin/check-cloudwatch-metric.rb
* /bin/check-cloudwatch-composite-metric.rb
* /bin/check-dynamodb-capacity.rb
* /bin/check-dynamodb-throttle.rb
* /bin/check-direct-connect-virtual-interfaces.rb
* /bin/check-ebs-burst-limit.rb
* /bin/check-ebs-snapshots.rb
* /bin/check-ec2-filter.rb
* /bin/check-ec2-network.rb
* /bin/check-ecs-service-health.rb
* /bin/check-efs-metric.rb
* /bin/check-elasticache-failover.rb
* /bin/check-elb-certs.rb
* /bin/check-elb-health-fog.rb
* /bin/check-elb-health-sdk.rb
* /bin/check-elb-health.rb
* /bin/check-elb-instances-inservice.rb
* /bin/check-elb-latency.rb
* /bin/check-elb-nodes.rb
* /bin/check-elb-sum-requests.rb
* /bin/check-emr-cluster.rb
* /bin/check-emr-steps.rb
* /bin/check-eni-status.rb
* /bin/check-instance-events.rb
* /bin/check-rds-events.rb
* /bin/check-rds-pending.rb
* /bin/check-rds.rb
* /bin/check-redshift-events.rb
* /bin/check-route53-domain-expiration.rb
* /bin/check-s3-object.rb
* /bin/check-s3-tag.rb
* /bin/check-ses-limit.rb
* /bin/check-ses-statistics.rb
* /bin/check-sqs-messages.rb
* /bin/check-subnet-ip-consumption.rb
* /bin/check-vpc-nameservers.rb
* /bin/check_vpc_vpn.py
* /bin/check_vpc_vpn.rb
* /bin/handler-ec2_node.rb
* /bin/handler-ses.rb
* /bin/handler-sns.rb
* /bin/metrics-autoscaling-instance-count.rb
* /bin/check-instances-count.rb
* /bin/metrics-asg.rb
* /bin/metrics-billing.rb
* /bin/metrics-ec2-count.rb
* /bin/metrics-ec2-filter.rb
* /bin/metrics-elasticache.rb
* /bin/metrics-elb-full.rb
* /bin/metrics-elb.rb
* /bin/metrics-emr-steps.rb
* /bin/metrics-rds.rb
* /bin/metrics-reservation-utilization.rb
* /bin/metrics-s3.rb
* /bin/metrics-ses.rb
* /bin/metrics-sqs.rb

## Usage

**handler-ses**

1. Configure [authentication](#authentication)
2. Enable the handler in `/etc/sensu/conf.d/handlers/ses.json`:
```
{
  "handlers": {
    "ses": {
      "type": "pipe",
      "command": "handler-ses.rb"
    }
  }
}
```
3. Configure the handler in `/etc/sensu/conf.d/ses.json`:
```
{
  "ses": {
    "mail_from": "sensu@example.com",
    "mail_to": "monitor@example.com",
    "region": "us-east-1",
    "subscriptions": {
      "subscription_name": {
        "mail_to": "teamemail@example.com"
      }
    }
  }
}
```

**handler-sns**

`handler-sns` can be used to send alerts to Email, HTTP endpoints, SMS, or any other [subscription type](http://docs.aws.amazon.com/sns/latest/dg/welcome.html) supported by SNS.

1. Create an SNS topic and subscription [[Docs]](http://docs.aws.amazon.com/sns/latest/dg/GettingStarted.html)
1. Configure [authentication](#authentication)
2. Enable the handler in `/etc/sensu/conf.d/handlers/sns.json`:
```
{
  "handlers": {
    "sns": {
      "type": "pipe",
      "command": "handler-sns.rb"
    }
  }
}
```
3. Configure the handler in `/etc/sensu/conf.d/sns.json`:
```
{
  "sns": {
    "topic_arn": "arn:aws:sns:us-east-1:111111111111:topic",
    "region": "us-east-1"
  }
}
```
## Installation

[Installation and Setup](http://sensu-plugins.io/docs/installation_instructions.html)

Note:  In addition to the standard installation requirements the installation of this gem will require compiling the nokogiri gem.  Due to this you'll need certain development packages on your system.

On Ubuntu systems run the following to install build dependencies:

```
sudo apt-get install build-essential libxml2-dev zlib1g-dev
```

On CentOS systems, run the following to install build dependencies:
```
sudo yum groupinstall -y "Development Tools"
sudo yum install -y libxml2-devel zlib-devel
```

If you'd like to avoid compiling nokogiri and other gems on every system where you need to install this plugin collection, please have a look at [the Sensu guide for pre-compiling plugin packages](https://docs.sensu.io/sensu-core/latest/guides/pre-compile-plugins/).

## Authentication

AWS credentials are required to execute these checks. Starting with AWS-SDK v2 there are a few
methods of passing credentials to the check:

1. Use a [credential file](http://docs.aws.amazon.com/sdk-for-ruby/v2/developer-guide/setup-config.html#aws-ruby-sdk-credentials-shared). Place the credentials in `~/.aws/credentials`. On Unix-like systems this is going to be `/opt/sensu/.aws/credentials`. Be sure to restrict the file to the `sensu` user.
```
[default]
aws_access_key_id = <access_key>
aws_secret_access_key = <secret_access_key>
```

2. Use an [EC2 instance profile](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html). If the checks are executing on an EC2 instance you can give the instance an IAM role and authentication will be handled automatically.

See the [AWS-SDK docs](http://docs.aws.amazon.com/sdkforruby/api/#Configuration) for more details on
credential configuration.

Some of the checks accept credentials with `aws_access_key` and `aws_secret_access_key` options
however this method is deprecated as it is insecure to pass credentials on the command line. Support
for these options will be removed in future releases.

No matter which authentication method is used you should restrict AWS API access to the minimum required to run the checks. In general this is done by limiting the sensu IAM user/role to the necessary `Describe` calls for the services being checked.
