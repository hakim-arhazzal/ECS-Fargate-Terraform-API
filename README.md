# ECS-Fargate-Terraform-API

## _AWS Fargate ECS Blue/Green Deployment Setup Using Terraform (Versioned Deployment) with 0 Downtime_

In this project, we’ll deploy a simple versioning ECS application with Blue/Green deployment and zero downtime deployment using AWS Fargate and AWS CI/CD pipelines. The entire infrastructure will be provisioned using Terraform (modular approach).

## Proposed Architecture

![alt text](https://github.com/hakim-arhazzal/ECS-Fargate-Terraform-API/blob/main/pictures/architecture.png?raw=true)

## Main goals
- Zero server maintenance in order to build and deploy new versions of an specific service (deployment take place after each new version)
- Zero Downtime deployment
- Automatic rollback in case of failure
- Easy to reproduce/duplicate configuration

## How it works!
This Project contains two main phases:
- Implementation and Configuration of a simple HTTP server App as Docker Image
- The Implementation of the Application in the CI/CD environment defined above

The solution will take care of:
- Spinning up an AWS ECS cluster
- Create an ECS task behind an AWS Application Load Balancer
- Register the initial version if the  application (Web Server) to run on your cluster
- Create a CodeDeploy application to deploy your tasks
- Create a CloudWatch Log Group to store logs from your App
- Generate a script to deploy the Docker app as a task for this ECS service using CodeDeploy
- Create a Route53 DNS A Record pointing the ALB

In order to leverage Zero Downtime deployment, it leans on a Blue Green deployment structure backed by AWS CodeDeploy and AWS Application Load Balancer. By looking to the blue sequence flows in the above picture you'll see how HTTPS requests are handled by the server. Basically the Load Balancer pick an instance from the active (blue or green) Target Group to actually handle the request.

During a deployment, as we can see in the red sequence flows, AWS CodeDeploy and AWS Application Load Balancer interact each other, ensuring that the traffic is re-routed from the blue to the green Target Group after a successful deployment.

- Upload your new Docker image into the ECR via AWS CodeBuild.
- Create and Deploy a task using your just uploaded ECR, and notify AWS CodeDeploy to start the deployment it self.
- AWS CodeDeploy will notify AWS ECS in order to spin up instances as defined on your task file.
- Once the tasks are running, all instances are registered into the green Target Group. If the health-check fails during the startup, the deployment is discarded and the instances are terminated.
- AWS CodeDeploy will re-route all traffic to the new deployed instances, while previous instances will have their connections gracefully drained - ensuring all request were finished before destroy them.

## Solution Implementation

## Phase 1:
The myapp folder contains a Simple HTTP server written in Nodejs
## What does it do
This container starts a webserver on port `8080` and returns back its current version on the path `/version`

## Phase 2:
**Step 1:** Create a codecommit repo and place the code given in the app folder
**Step 2:** Create a Elastic Container Registry and use the Dockerfile given at the app folder to create an image and push in to the registry.This image will be used to initially deploy our ECS service.
**Step 3:** Create a file named `buildspec.yml` in our codecommit repo with following content. This file will be utilized by Code Build to build our image.Replace <ECR_REPO_URI> with your ECR repo’s URI.

```sh
version: 0.2
phases:
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws --version
      - echo $AWS_DEFAULT_REGION
      - $(aws ecr get-login --region $AWS_DEFAULT_REGION --no-include-email)
      - REPOSITORY_URI=<ECR_REPO_URI>
      - REPOSITORY_NAME=test-api
      - COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - IMAGE_TAG=${COMMIT_HASH:=latest}
  build:
    commands:
      - echo Build started on `date`
      - echo Building the Docker image...
      - docker build -t $REPOSITORY_NAME .
      - docker tag $REPOSITORY_NAME:latest $REPOSITORY_URI:latest
  post_build:
    commands:
      - echo Build completed on `date`
      - docker push $REPOSITORY_URI:latest
      - printf '{"ImageURI":"%s"}' $REPOSITORY_URI:latest > imageDetail.json
artifacts:
  files:
    - 'image*.json'
    - 'appspec.yaml'
    - 'taskdef.json'
  secondary-artifacts:
    DefinitionArtifact:
      files:
        - appspec.yaml
        - taskdef.json
    ImageArtifact:
      files:
        - imageDetail.json
```
**Step 4:** Create a file named `appspec.yml` in our codecommit repo with following content.
```sh
version: 0.0
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: <TASK_DEFINITION>
        LoadBalancerInfo:
          ContainerName: "api-test-container"
          ContainerPort: 8080
```
Important thing to note down here is ContainerName and ContainerPort.When we’ll be creating our setup using Terraform,we’ll specify these settings there also. If your container name and port is different, then make sure you change it here as well as in the Terraform code(terraform.tfvars file).

**Step 5:** Now let move on to `terraform_ecs_bluegreen` folder to get the terraform code. Specify your variables’ values in terraform.tfvars and execute the following commands:
```sh
terraform init
terraform validate
terraform plan
terraform apply --auto-approve
```
This will create a VPC along with Private/Public subnets, required IAM roles, Security Groups, ALB with 2 listeners/target groups(port 80 for the main listener and port 8080 for Blue/Green testing), ECS Cluster along with a Fargate service and a CodePipeline for continuous deployment.
**Step 6:** Once Terraform execution is completed, access your Route 53 DNS to make sure things are working.
![alt text](https://github.com/hakim-arhazzal/ECS-Fargate-Terraform-API/blob/main/pictures/1.png?raw=true)
![alt text](https://github.com/hakim-arhazzal/ECS-Fargate-Terraform-API/blob/main/pictures/2.png?raw=true)
**Step 7:** Now make a change to `index.js` file and it will trigger a new deployment which will create new ECS tasks with updated code. You can access the updated code @ <ROUTE53_DNS>:8080.
If you see our terraform.tfvars file, we’ve specified to shift 10% of traffic every minute to new task set and once traffic is entirely moved to new deployment, previous task set will be deleted after 30 minutes.
```sh
deployment_config_name          ="CodeDeployDefault.ECSLinear10PercentEvery1Minutes"
termination_wait_time_in_minutes = 30
```
**Step 8:** Check the deployment progress and how traffic is getting gradully re-routed to new deployment.
![alt text](https://github.com/hakim-arhazzal/ECS-Fargate-Terraform-API/blob/main/pictures/3.png?raw=true)
Once build is successful and deployment is started, you can go to Code Deploy console and check the progress.
![alt text](https://github.com/hakim-arhazzal/ECS-Fargate-Terraform-API/blob/main/pictures/7.png?raw=true)
At this point,2 new ECS fargate tasks will be launched and traffic shifting has already started.

Now if you access our DNS, you’ll see some requests are serving updated version(I changed version from `1.0.1` to `2.0.0`).
![alt text](https://github.com/hakim-arhazzal/ECS-Fargate-Terraform-API/blob/main/pictures/6.png?raw=true)
Once the entire traffic is shifted to new deployment, it’ll wait for 30 minuets an then delete the previous task set. At this point our Blue/Green deployment is completed!
![alt text](https://github.com/hakim-arhazzal/ECS-Fargate-Terraform-API/blob/main/pictures/3.png?raw=true)
**Cleanup:** Make our codepipeline bucket(default bucket name is dev-bucket1998)empty and run `terraform destroy` to delete the infrastructure we created.
