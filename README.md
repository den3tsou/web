# Set up the infra

The infra is setup by
* VPC with 3 public subnets and 3 private subnet
* Application Load Balancer
* ECS with Fargate Spot instance for saving only due to this is a test
* ECR
* A simple web server written in Golang packaged by container

The infra is built by terraform and AWS. Make sure you have the following
* [AWS account](https://aws.amazon.com/resources/create-account/)
* [aws cli](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
* [Terraform](https://developer.hashicorp.com/terraform/install)
* [AWS credential](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html)

Build the infra structure by the following commands
```sh
cd infra
terraform init

# The following command should provide the load balancer DNS in the end.
# You will need the DNS to access the application
terraform apply

./push_image_to_ecr.sh
```

# What else you would do with your website, and how you would go about doing it if you had more time.
* Only allow HTTPS traffic by
  + Creating a custom domain 
  + Generating TLS certificate by AWS Certificate Manager
  + Add HTTPS listener on Application Load Balancer
  + Remove the HTTP listener on Application Load Balancer
* Set up a redirect to HTTPS listener on the HTTP listener side to have good user experience
* Add autoscaling to Fargate, so the website can adopt to different volume of the traffic
* Have a right balance of Fargate and Fargate Spot to have the benefits of cost saving and on demand instance to use

# Alternative solutions that you could have taken but didn’t and explain why.
* API Gateway + Lambda
  + This setup is fine for a small team. But it is getting harder and harder for the development flow after the team gets bigger.
    The integration point is in the AWS itself which means it will be a lot of effort to allow devs to develop in this pattern locally
+ EC2 + Load Balancer + AutoScaling Group
  + This is a similar pattern as Fargate. But Fargate provides better scalability. Every single scaling of EC2 instance takes 2-3 mins at least while
    Fargate can be immediate most of the time.
# What would be required to make this a production grade website that would be developed on by various development teams. The more detail, the better!
* CI
  + The integration point of the system, all tests except e2e tests should be run here
  + Linter
  + config validation
  + build the image (if container technology is used)
  + This can be set up to run components relevant to the current change in large codebase to trade the comprehensive test suites, linter and config validation
    with the time to finish CI.
* CD
  + Canary Deployment
  + Blue Green deployment
  + running E2E tests before switch the traffic to the new deployment
* Security
  + There should be a tool to regularly scan the production system to make sure there is no potential security risk
  + Scan the codebase to make sure not potential security risk, for example password in the codebase
  + Scan the container image to make sure not potential security risk
  + Credential management - credentials should be managed in this system rather than hardcode in other system to enhance security
* Observability and monitoring
  + Centralised log server - It is always good to have one single place to see logs of the whole system rather than going to individual instance to
    figure out what's going on
  + Alert on common resources like CPU, memory, networking and disk space
  + Dashboards for common metrics, dashboards can be used for either the data for feature development or the status of the current system
* Disaster recover
  + On call mechanism - The right process to go through on call, for example, impact assessment, disaster recovery and escalation
  + Chaos Engineering - Periodically test the resilience and reliability and the time to recover of the production system
  + Runbook for potentially problem
  + Alerts with Runbook, so the oncall people can resolve the issue quickly
* Load testing
  + Easy way for devs to test new features on performance critical systems
