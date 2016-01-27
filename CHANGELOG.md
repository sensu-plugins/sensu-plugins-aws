#Change Log
This project adheres to [Semantic Versioning](http://semver.org/).

This CHANGELOG follows the format listed at [Keep A Changelog](http://keepachangelog.com/)

## Unreleased
### Added
- check-ec2-cpu_balance.rb: scans for any t2 instances that are below a certain threshold of cpu credits
- check-instance-health.rb: adding ec2 instance health and event data

### Changed
- Update to aws-sdk 2.2.11 and aws-sdk-v1 1.66.0

### Fixed
- check-vpc-vpn.rb: fix execution error by running with aws-sdk-v1

## [2.1.0] - 2016-01-15
### Added
- Added check-beanstalk-health
- check-elb-health-sdk.rb: add option for warning instead of critical when unhealthy instances are found
- check-rds.rb: add M4 instances
- handler-sns.rb: add option to use a template to render body mail
- check-rds-events.rb: add RDS event message to output
- Added check-cloudwatch-metric that checks the values of cloudwatch metrics
- Added check-beanstalk-elb-metric that checks an ELB used in a Beanstalk environment
- Added check-certificate-expiry that checks the expiration date of certificates loaded into IAM
- Added test cases for check-certificate-expiry.rb

### Changed
- handler-ec2_node.rb: Update to new API event naming and simplifying ec2_node_should_be_deleted method and fixing match that will work with any user state defined, also improved docs
- metrics-elb-full.rb: flush hash in-between iterations
- check-ses-limit.rb: move to AWS-SDK v2, use common module, return unknown on empty responses

### Fixed
- metrics-memcached.rb: Fixed default scheme
- Fix typo in cloudwatch comparison check

## [2.0.1] - 2015-11-03
### Changed
- pinned all dependencies
- set gemspec to require > `2.0.0`

Nothing new added, this is functionally identical to `2.0.0`. Doing a github release which for some reason failed even though a gem was built and pushed.

## [2.0.0] - 2015-11-02

WARNING: This release drops support for Ruby 1.9.3, which is EOL as of 2015-02.

### Added
- Added check-beanstalk-health to get beanstalk health
- Added check-cloudwatch-alarm to get alarm status
- Added connection metric for check-rds.rb
- Added check-s3-bucket that checks S3 bucket existence
- Added check-s3-object that checks S3 object existence
- Added check-emr-cluster that checks EMR cluster existence
- Added check-vpc-vpn that checks the health of VPC VPN connections

### Fixed
- handler-ec2_node checks for state_reason being nil prior to code access
- handler-ec2_node checks for client aws config block before using client name
- Cosmetic fixes to metrics-elb, check-rds, and check-rds-events
- Return correct metrics values in check-elb-sum-requests

### Removed
- Removed Ruby 1.9.3 support

## [1.2.0] - 2015-08-04
### Added
- Added check-ec2-filter to compare filter results to given thresholds
- Added check-vpc-nameservers, which given a VPC will validate the name servers in the DHCP option set.

### Fixed
- handler-ec2_node accounts for an empty instances array

## [1.1.0] - 2015-07-24
### Added
- Added new AWS SES handler - handler-ses.rb
- Add metrics-ec2-filter to store node ids and count matching a given filter
- Check to alert on unlisted EIPs

## [1.0.0] - 2015-07-22

WARNING:  This release contains major breaking changes that will impact all users.  The flags used for access key and secret key have been standardized accross all plugins resulting in changed flags for the majority of plugins. The new flags are -a AWS_ACCESS_KEY and -k AWS_SECRET_KEY.

### Added
- EC2 node handler will now remove nodes terminated by a user
- Transitioned EC2 node handler from fog to aws sdk v2
- Allowed ignoring nil values returned from Cloudwatch in the check-rds plugin. Previously if Cloudwatch fell behind you would be alerted
- Added support for checking multiple ELB instances at once by passing a comma separated list of ELB instance names in metrics-elb-full.rb
- Added check-autoscaling-cpucredits.rb for checking T2 instances in autoscaling groups that are running low on CPU credits
- Updated the fog and aws-sdk gems to the latest versions to improve performance, reduce 3rd party gem dependencies, and add support for newer AWS features.
- Add metrics-ec2-filter to store node ids and count matching a given filter

### Fixed
- Renamed autoscaling-instance-count-metrics.rb -> metrics-autoscaling-instance-count.rb to match our naming scheme
- Reworked check-rds-events.rb to avoid the ABCSize warning from rubocop
- Corrected the list of plugins / files in the readme
- Make ELB name a required flag for the metrics ELB plugins to prevent nil class errors when it isn't provided
- Properly document that all plugins default to us-east-1 unless the region flag is passed
- Fix the ELB metrics plugins to properly use the passed auth data
- Fixed the metrics-elb-full plugin to still add the ELB instance name when a graphite schema is appended
- Fixed all plugins to support passing the AWS access and secret keys from shell variables. Plugin help listed this as an option for all plugins, but the support wasn't actually there.

## [0.0.4] - 2015-07-05
### Added
- Added the ability to alert on un-snapshotted ebs volumes

## [0.0.3] - 2015-06-26
### Fixed
- Access key and secret key should be optional
- Added 3XX metric collection to the ELB metrics plugins
- Fixed the metric type for SurgeQueueLength ELB metrics
- Fixed logic for ec2 instance event inclusion

## [0.0.2] - 2015-06-02
### Fixed
- added binstubs

### Changed
- removed cruft from /lib

## [0.0.1] - 2015-05-21
### Added
- initial release
