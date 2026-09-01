# Gatus on AWS ECS Fargate

For this project, I deployed Gatus to AWS using Docker, ECS Fargate, Terraform and GitHub Actions.

Gatus is an open-source health monitoring application. Rather than just running it locally, I wanted to take it through the full deployment process and build the AWS infrastructure around it.

That meant containerising the application, setting up the networking, keeping the ECS workload private, adding a load balancer and HTTPS, moving the infrastructure into Terraform, and finally automating deployments with GitHub Actions.

The application now runs on ECS Fargate inside private subnets and is accessed through an Application Load Balancer using a custom domain.

---

## Overview

Here's what I used to build the project:

- **Docker** – containerising Gatus
- **Amazon ECR** – storing the Docker images
- **Amazon ECS Fargate** – running the container
- **Application Load Balancer** – receiving and forwarding web traffic
- **Amazon VPC** – separating the public and private parts of the network
- **NAT Gateway** – outbound internet access for the private subnets
- **Route 53** – DNS and the custom domain
- **AWS Certificate Manager** – HTTPS certificate
- **CloudWatch** – container logs
- **Terraform** – building and managing the AWS infrastructure
- **GitHub Actions** – automated deployments
- **GitHub OIDC** – allowing GitHub Actions to authenticate to AWS without permanent AWS access keys

A big part of this project for me was getting the networking right.

I didn't want to give the ECS task a public IP just because it was the easiest way to make the application accessible. Instead, the ALB sits in the public subnets and the Gatus task stays in the private subnets.

---

## Architecture

![Gatus AWS Architecture](docs/screenshots/Gatus%20Architecture.png)

At a high level, incoming traffic follows this path:

```text
User
  |
  v
Route 53 / Custom Domain
  |
  v
Application Load Balancer
  |
  |-- HTTP :80 --> 301 Redirect to HTTPS
  |
  `-- HTTPS :443 + ACM Certificate
          |
          v
     Target Group
       HTTP :8080
          |
          v
      ECS Fargate
          |
          v
         Gatus
```

When someone visits the domain over HTTP, the ALB redirects them to HTTPS.

The ACM certificate is attached to the HTTPS listener on port `443`. Once the ALB handles the HTTPS connection, it forwards the request to the Gatus target on port `8080`.

The important part is that users never connect directly to the ECS task.

---

## Design Features

### Private ECS Workload

The Gatus task runs inside the private subnets with:

```hcl
assign_public_ip = false
```

So even though the application is available publicly, the container itself isn't directly exposed to the internet.

Traffic to port `8080` is only allowed from the ALB security group.

### Two Availability Zones

I split the VPC across:

```text
eu-north-1a
eu-north-1b
```

Each Availability Zone has a public and private subnet.

The ALB uses both public subnets, while the ECS service can place the Gatus task in either of the private subnets.

### HTTPS

The application is available over HTTPS using AWS Certificate Manager.

Requests arriving over HTTP on port `80` are redirected to HTTPS on port `443`.

### Health Checks

I set up two levels of health checking.

The ECS task definition checks the application from inside the container using:

```text
http://localhost:8080/health
```

The ALB target group also checks:

```text
/health
```

and expects a `200` response.

This was useful because a task showing as "running" in ECS doesn't necessarily mean the application inside it is actually ready to receive traffic.

### Infrastructure as Code

The AWS infrastructure is defined in Terraform.

This was a big improvement over relying on resources I'd created manually in the AWS Console because I could see the infrastructure as code and reproduce it much more easily.

### Automated Deployment

GitHub Actions handles the application deployment.

When the deployment workflow runs from `main`, it builds the Docker image, pushes it to ECR and triggers a new ECS deployment.

### OIDC Authentication

I used GitHub OIDC to authenticate the deployment workflow to AWS.

This means I don't need to keep permanent AWS access keys in GitHub for the pipeline.

---

## Project Layout

The main parts of the project are organised like this:

```text
gatus-source/
│
├── .github/
│   └── workflows/
│       └── deploy.yml
│
├── docs/
│   └── screenshots/
│       ├── Gatus Architecture.png
│       ├── Gatus Dashboard.png
│       ├── Gatus Targets.png
│       └── Gatus-Service ECS.png
│
├── infra/
│   ├── .terraform.lock.hcl
│   ├── acm.tf
│   ├── alb.tf
│   ├── cloudwatch.tf
│   ├── ecs.tf
│   ├── github-oidc.tf
│   ├── iam.tf
│   ├── nat.tf
│   ├── outputs.tf
│   ├── provider.tf
│   ├── route53.tf
│   ├── security-groups.tf
│   ├── variables.tf
│   ├── versions.tf
│   └── vpc.tf
│
├── Dockerfile
├── .dockerignore
├── .gitignore
├── config.yaml
├── go.mod
├── go.sum
├── main.go
└── README.md
```

The rest of the repository contains the upstream Gatus source used to build the application.

I moved all of my Terraform into `infra/` so there's a clear separation between the application and the AWS infrastructure I've added around it.

---

## Networking

The infrastructure is deployed in `eu-north-1` inside a dedicated VPC:

```text
10.0.0.0/16
```

I split the VPC into four subnets:

| Subnet | CIDR | Availability Zone | Used for |
| --- | --- | --- | --- |
| Public A | `10.0.1.0/24` | `eu-north-1a` | ALB + NAT Gateway |
| Private A | `10.0.2.0/24` | `eu-north-1a` | ECS |
| Public B | `10.0.3.0/24` | `eu-north-1b` | ALB |
| Private B | `10.0.4.0/24` | `eu-north-1b` | ECS |

### Public Subnets

The two public subnets use a route table with:

```text
0.0.0.0/0 -> Internet Gateway
```

The ALB spans both public subnets.

The NAT Gateway sits in Public Subnet A and has an Elastic IP attached to it.

### Private Subnets

The ECS task doesn't have a public IP, but it can still need to make outbound connections.

Instead of exposing the task publicly, the private subnets use:

```text
0.0.0.0/0 -> NAT Gateway
```

So outbound traffic follows:

```text
ECS Task
   |
   v
Private Subnet
   |
   v
Private Route Table
   |
   v
NAT Gateway
   |
   v
Internet Gateway
   |
   v
Internet
```

This was one of the parts of the project that helped me understand the difference between making a workload publicly reachable and simply allowing it to initiate outbound traffic.

---

## Security

I kept the ALB and ECS security rules separate.

### ALB Security Group

The ALB accepts:

```text
TCP 80  <- 0.0.0.0/0
TCP 443 <- 0.0.0.0/0
```

Port `80` is there so HTTP requests can be redirected to HTTPS.

### ECS Security Group

The ECS security group allows:

```text
TCP 8080 <- ALB Security Group
```

I didn't open port `8080` to:

```text
0.0.0.0/0
```

Instead, the ECS security group trusts the ALB security group.

So the inbound route is:

```text
Internet -> ALB -> ECS -> Gatus
```

rather than:

```text
Internet -> ECS
```

Together with `assign_public_ip = false`, this keeps the Gatus workload private.

---

## HTTPS and DNS

I used Route 53 for DNS and AWS Certificate Manager for the HTTPS certificate.

The certificate is validated through DNS and attached to the HTTPS ALB listener.

The ALB has two listeners:

```text
HTTP  :80  -> 301 Redirect -> HTTPS
HTTPS :443 -> Target Group
```

TLS terminates at the ALB.

From there, the ALB sends the request to Gatus internally over HTTP on port `8080`.

---

## ECS Fargate

Gatus runs as an ECS Fargate task using `awsvpc` networking.

The service currently uses:

```text
Launch type:     FARGATE
Desired count:   1
Container port:  8080
Public IP:       Disabled
```

The ECS service is configured to use both private subnets, although the current desired count means only one task is running.

Container logs are sent to CloudWatch using the `awslogs` log driver.

---

## CI/CD

The deployment workflow is stored in:

```text
.github/workflows/deploy.yml
```

It runs when changes are pushed to `main`.

The pipeline looks like this:

```text
Push to main
     |
     v
GitHub Actions
     |
     v
Authenticate to AWS with OIDC
     |
     v
Login to ECR
     |
     v
Build Docker Image
     |
     v
Push Image to ECR
     |
     v
Trigger New ECS Deployment
     |
     v
Wait for ECS to Stabilise
```

### Image Tagging

Each Docker build gets two tags:

```text
Git commit SHA
latest
```

The commit SHA gives me a way to tie an image back to the exact Git commit that created it, while `latest` points to the newest image.

### GitHub OIDC

The workflow uses:

```yaml
permissions:
  contents: read
  id-token: write
```

GitHub then assumes the AWS IAM role configured for the repository.

I chose this instead of putting long-lived AWS access keys into GitHub secrets.

### ECS Deployment

After pushing the image, the workflow forces a new ECS deployment.

It then waits for the service to become stable before marking the workflow as successful.

That means the workflow doesn't finish immediately after telling ECS to redeploy; it waits for ECS to complete the deployment.

---

## Logging

Gatus sends its container logs to CloudWatch.

This ended up being particularly useful while troubleshooting.

ECS might tell me that a task has started, but if Gatus fails during startup or isn't listening where I expect it to be, the CloudWatch logs give me a much better idea of what's actually happening inside the container.

---

## Running the Project Locally

You don't need an AWS account to run the application itself.

If you just want to try the project locally, Git and Docker are enough.

### Requirements

Check that you have both installed:

```bash
git --version
docker --version
```

### 1. Clone the Repository

```bash
git clone https://github.com/ahmadjubair101/ECS-Project.git
cd gatus-source
```

### 2. Build the Docker Image

From the root of the project:

```bash
docker build -t gatus .
```

You can check the image was created with:

```bash
docker images
```

### 3. Run the Container

```bash
docker run --rm -p 8080:8080 --name gatus-local gatus
```

This maps port `8080` on your machine to port `8080` inside the container.

### 4. Open Gatus

Go to:

```text
http://localhost:8080
```

You should see the Gatus dashboard.

### 5. Check the Health Endpoint

In another terminal:

```bash
curl http://localhost:8080/health
```

You can also confirm the container is running with:

```bash
docker ps
```

### 6. Stop the Container

If it's running in the foreground, use:

```text
Ctrl+C
```

Because I started it with `--rm`, Docker removes the container after it stops.

If I change the application or configuration, I can simply rebuild and run it again:

```bash
docker build -t gatus .
docker run --rm -p 8080:8080 --name gatus-local gatus
```

That's the process I use to check the container locally before deploying a change to AWS.

---

## Reproducing the AWS Deployment

If you want to reproduce the full AWS setup rather than just run Gatus locally, you'll also need:

- An AWS account
- AWS CLI
- Terraform
- Docker
- Git
- A GitHub repository
- A domain that can be managed through Route 53

Check the main tools first:

```bash
aws --version
terraform --version
docker --version
git --version
```

### 1. Clone the Project

```bash
git clone https://github.com/ahmadjubair101/ECS-Project.git
cd gatus-source
```

### 2. Test Gatus Locally

Before touching AWS, make sure the image works:

```bash
docker build -t gatus .
docker run --rm -p 8080:8080 gatus
```

Then:

```bash
curl http://localhost:8080/health
```

### 3. Configure Terraform

Move into the infrastructure directory:

```bash
cd infra
```

Create:

```text
terraform.tfvars
```

and provide the values required by `variables.tf`.

I keep `terraform.tfvars` out of Git because it's environment-specific and shouldn't be part of the public repository.

### 4. Initialise Terraform

```bash
terraform init
```

### 5. Check the Terraform

Format the files:

```bash
terraform fmt -recursive
```

Then validate them:

```bash
terraform validate
```

### 6. Review the Plan

```bash
terraform plan
```

I always review the plan before applying it so I can see what Terraform is about to create or change.

### 7. Apply the Infrastructure

```bash
terraform apply
```

Review the plan again and confirm the apply.

### 8. Configure the GitHub Repository

The deployment workflow uses these GitHub repository variables:

```text
AWS_REGION
AWS_ROLE_ARN
ECR_REPOSITORY
ECS_CLUSTER
ECS_SERVICE
CONTAINER_NAME
```

They tell the workflow which AWS region, IAM role, ECR repository and ECS resources to use.

### 9. Deploy

Once everything is configured, push the application changes to `main`.

GitHub Actions then:

```text
Authenticates to AWS
        |
        v
Logs into ECR
        |
        v
Builds the Docker image
        |
        v
Tags it with SHA + latest
        |
        v
Pushes both tags to ECR
        |
        v
Triggers a new ECS deployment
        |
        v
Waits for the service to stabilise
```

### 10. Verify It

I don't rely on just one status to decide whether the deployment worked.

First, I check ECS:

```text
Desired tasks: 1
Running tasks: 1
```

Then I check the ALB target group:

```text
Healthy
```

I also check that the custom domain loads over HTTPS and that HTTP redirects correctly.

Finally, the deployed health endpoint can be checked with:

```bash
curl -fsS -o /dev/null -w '%{http_code}\n' https://tm.jubair-gatusmonitoringapp.co.uk/health
```

A healthy response should return:

```text
200
```

---

## Deployment Evidence

### Gatus Dashboard

Gatus running through the deployed AWS environment:

![Gatus Dashboard](docs/screenshots/Gatus%20Dashboard.png)

### ECS Service

The ECS service running the Gatus task:

![Gatus ECS Service](docs/screenshots/Gatus-Service%20ECS.png)

### Healthy ALB Target

The Gatus target registered as healthy behind the ALB:

![Gatus Healthy Target](docs/screenshots/Gatus%20Targets.png)

These were the main checks I used to confirm that the application wasn't just running, but was actually reachable through the full AWS setup.

---

## Cost Considerations

This is a project environment, so I kept the deployment fairly small.

The ECS service currently runs one Fargate task:

```text
desired_count = 1
```

One thing I had to keep in mind is that a small workload doesn't necessarily mean every AWS service is cheap.

The NAT Gateway has an hourly cost as well as data processing charges, and the Application Load Balancer also costs money while it's running.

For a learning project like this, destroying infrastructure when I'm no longer using it is an important part of keeping the AWS bill under control.

---

## Known Limitations

There are a few parts of the setup I'd change if I were building this for a larger production environment.

### One ECS Task

The service currently has:

```text
desired_count = 1
```

ECS can place that task in either private subnet, but there's still only one running copy of Gatus.

For better availability, I'd run multiple tasks across the two Availability Zones.

### One NAT Gateway

There's currently one NAT Gateway in Public Subnet A.

Both private subnets use it for outbound access.

I went with one NAT Gateway to keep the project simpler and reduce the cost, but it does mean the NAT layer isn't highly available across both AZs.

A more resilient setup would have a NAT Gateway in each Availability Zone, with each private subnet using the NAT Gateway in its own AZ.

### HTTP Between the ALB and Gatus

HTTPS terminates at the ALB.

The ALB then communicates with Gatus over HTTP on port `8080`.

That keeps the setup simpler for this project. In an environment with stricter security requirements, encryption between the ALB and the application could also be considered.

### CI/CD Doesn't Run Tests Yet

The current workflow builds the Docker image, pushes it to ECR and deploys it.

It doesn't currently have a separate automated test or security scanning stage.

That's something I'd add before treating the pipeline as production-ready.

---

## Future Improvements

There are a few things I'd like to add if I take the project further:

- Run more than one ECS task for better availability
- Add a NAT Gateway per Availability Zone
- Add automated tests before deployment
- Validate Terraform through GitHub Actions
- Scan Docker images for vulnerabilities
- Add Terraform security scanning
- Add CloudWatch alarms
- Add notifications for deployment or application failures
- Separate development and production environments
- Move Terraform state to a remote backend
- Add infrastructure plan checks before Terraform changes are applied

I haven't added these just to make the project look more complicated. They're things I'd look at next based on the limitations of the current setup.

---

## Keeping Local Files Out of Git

Terraform creates a few files locally that I don't want in the repository.

My `.gitignore` excludes:

```text
infra/.terraform/
infra/*.tfstate
infra/*.tfstate.*
infra/*.tfvars
infra/*.tfplan
```

Terraform state is especially important to keep out of a public repository because it can contain details about the infrastructure and potentially sensitive values.

I do commit:

```text
infra/.terraform.lock.hcl
```

because the lock file helps keep the Terraform provider versions consistent.

I also exclude environment files, AWS credentials, private keys and local IDE files.

---

## What I Learned

The biggest takeaway from this project was understanding how all the individual AWS services fit together.

Before building it, it's easy to look at ECS, ALBs, target groups, NAT Gateways and route tables as separate AWS services. Working through the deployment made it much clearer how traffic actually moves between them.

The networking was probably the part I learned the most from. I had to understand why the ALB belongs in the public subnets, why the ECS task can stay private, and how the task can still get outbound internet access without having its own public IP.

Health checks were another useful lesson. A running ECS task doesn't automatically mean the application is working. Having both the container health check and ALB health check helped me see the difference.

Terraform also made a big difference to how I approached the infrastructure. Once the setup was defined in code, it became much easier to see what I'd actually built instead of having resources spread across different pages in the AWS Console.

The CI/CD part brought everything together. Instead of manually rebuilding the image, pushing it to ECR and restarting ECS every time, GitHub Actions now handles that deployment flow for me.

More than anything, this project helped me understand the full path from code running on my machine to a containerised application running privately in AWS and being served securely over a custom domain.

---

## Credits

Gatus is an open-source health monitoring project created by TwiN.

I used Gatus as the application for this project and built the Docker, AWS infrastructure, Terraform and CI/CD deployment around it.
