require 'aws-sdk'

DEPLOYING_SERVICE = {
  service_arn: 'arn:aws:ecs:us-east-1:123456789012:service/my-deploying-ecs-service',
  service_name: 'my-deploying-ecs-service',
  cluster_arn: 'arn:aws:ecs:us-east-1:123456789012:cluster/default',
  status: 'ACTIVE',
  desired_count: 1,
  running_count: 2,
  pending_count: 0
}.freeze

OK_SERVICE = {
  service_arn: 'arn:aws:ecs:us-east-1:123456789012:service/my-ecs-service',
  service_name: 'my-healthy-ecs-service',
  cluster_arn: 'arn:aws:ecs:us-east-1:123456789012:cluster/default',
  status: 'ACTIVE',
  desired_count: 1,
  running_count: 1,
  pending_count: 0
}.freeze

WARN_SERVICE = {
  service_arn: 'arn:aws:ecs:us-east-1:123456789012:service/my-unstable-ecs-service',
  service_name: 'my-unstable-ecs-service',
  cluster_arn: 'arn:aws:ecs:us-east-1:123456789012:cluster/default',
  status: 'ACTIVE',
  desired_count: 2,
  running_count: 1,
  pending_count: 0
}.freeze

CRIT_SERVICE = {
  service_arn: 'arn:aws:ecs:us-east-1:123456789012:service/my-broken-ecs-service',
  service_name: 'my-broken-ecs-service',
  cluster_arn: 'arn:aws:ecs:us-east-1:123456789012:cluster/default',
  status: 'ACTIVE',
  desired_count: 1,
  running_count: 0,
  pending_count: 0
}.freeze

DISABLED_SERVICE = {
  service_arn: 'arn:aws:ecs:us-east-1:123456789012:service/my-disabled-ecs-service',
  service_name: 'my-disabled-ecs-service',
  cluster_arn: 'arn:aws:ecs:us-east-1:123456789012:cluster/default',
  status: 'ACTIVE',
  desired_count: 0,
  running_count: 0,
  pending_count: 0
}.freeze

ALL_SERVICES = [OK_SERVICE, WARN_SERVICE, CRIT_SERVICE, DISABLED_SERVICE, DEPLOYING_SERVICE].freeze

def stub_default
  describe_services = {
    services: ALL_SERVICES
  }

  list_services = {
    service_arns: describe_services[:services].collect { |s| s[:service_arn] }
  }

  Aws.config = {
    stub_responses: {
      describe_services: describe_services,
      list_services: list_services
    }
  }
end

def stub_critical
  describe_services = {
    services: [CRIT_SERVICE]
  }

  list_services = {
    service_arns: describe_services[:services].collect { |s| s[:service_arn] }
  }

  Aws.config = {
    stub_responses: {
      describe_services: describe_services,
      list_services: list_services
    }
  }
end

def stub_warn
  describe_services = {
    services: [WARN_SERVICE]
  }

  list_services = {
    service_arns: describe_services[:services].collect { |s| s[:service_arn] }
  }

  Aws.config = {
    stub_responses: {
      describe_services: describe_services,
      list_services: list_services
    }
  }
end

def stub_ok
  describe_services = {
    services: [OK_SERVICE, DEPLOYING_SERVICE]
  }

  list_services = {
    service_arns: describe_services[:services].collect { |s| s[:service_arn] }
  }

  Aws.config = {
    stub_responses: {
      describe_services: describe_services,
      list_services: list_services
    }
  }
end
