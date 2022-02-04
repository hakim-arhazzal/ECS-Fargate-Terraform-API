vpc_cidr                         = "10.6.0.0/16"
private_subnet                   = { count = 2, newbits = 10, netnum = 0 }
public_subnet                    = { count = 2, newbits = 10, netnum = 4 }
vpc_name                         = "ecs_vpc"
ecs_cluster_name                 = "fargate-cluster"
docker_container_port            = 8080
ecs_service_name                 = "api-test"
docker_image_url                 = "<ACCOUNT_ID>.dkr.ecr.eu-west-3.amazonaws.com/test-api:latest" #Please enter your Account Id
memory                           = 512
desired_task_number              = 2
cpu                              = 256
repo_name                        = "myapp"
env_name                         = "dev"
termination_wait_time_in_minutes = 30
deployment_config_name           = "CodeDeployDefault.ECSLinear10PercentEvery1Minutes"
dns_name                         = "example.com" #Please entrer your hosted zone in Route53
