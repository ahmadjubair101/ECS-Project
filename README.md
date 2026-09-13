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

The AWS infrastructure is managed with Terraform and split into reusable modules for networking, security, IAM, ECS, the Application Load Balancer, ACM, Route 53, CloudWatch and GitHub OIDC.

The root Terraform configuration connects these modules together rather than defining every AWS resource in one large configuration.

During the refactor from flat Terraform files to modules, I used Terraform `moved` blocks so existing resources could be moved to their new module addresses without being destroyed and recreated.

Terraform state is stored remotely in an encrypted Amazon S3 backend rather than being kept only on my local machine.

The state bucket has:

* S3 versioning enabled
* server-side encryption enabled
* public access blocked
* Terraform state locking enabled

This gives the local Terraform workflow and GitHub Actions a shared source of truth for the infrastructure and prevents multiple Terraform operations from modifying the state at the same time.


## Project Layout

I separated the application, infrastructure and automation so each part of the project has a clear responsibility.

```text
ECS-Project/
│
├── .github/
│   └── workflows/
│       ├── deploy.yml
│       └── terraform.yml
│
├── app/
│   ├── Dockerfile
│   ├── .dockerignore
│   ├── Makefile
│   ├── config.yaml
│   ├── go.mod
│   ├── go.sum
│   ├── main.go
│   └── ...Gatus source code
│
├── docs/
│   └── screenshots/
│
├── infra/
│   ├── bootstrap/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── modules/
│   │   ├── alb/
│   │   ├── certificate/
│   │   ├── dns/
│   │   ├── ecs/
│   │   ├── github-oidc/
│   │   ├── iam/
│   │   ├── monitoring/
│   │   ├── networking/
│   │   ├── security/
│   │   └── terraform-ci/
│   │
│   ├── main.tf
│   ├── moved.tf
│   ├── outputs.tf
│   ├── provider.tf
│   ├── route53.tf
│   ├── variables.tf
│   ├── versions.tf
│   └── .terraform.lock.hcl
│
├── .gitignore
├── LICENSE
└── README.md
```

The application and its Docker build context live inside `app/`, while all AWS infrastructure is managed from `infra/`.

Terraform is split into reusable modules rather than keeping every resource in a single flat configuration. The root module connects the individual components together and passes outputs between modules.

The `bootstrap/` configuration is kept separate because it creates the S3 bucket used by Terraform's own remote backend.

There are also two separate GitHub Actions workflows:

* `deploy.yml` handles application delivery by building the Docker image, pushing it to Amazon ECR and updating the ECS service.
* `terraform.yml` handles infrastructure changes by running Terraform formatting, validation, planning and apply steps.

This keeps application deployment and infrastructure deployment separate instead of giving one workflow responsibility for everything.

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

I use two separate GitHub Actions workflows so application deployment and infrastructure deployment are handled independently.

### Application Deployment

The application deployment workflow is stored in:

```text
.github/workflows/deploy.yml
```

When changes are pushed to `main`, the workflow:

1. Checks out the repository.
2. Authenticates to AWS using GitHub OIDC.
3. Logs in to Amazon ECR.
4. Builds the Docker image from the `app/` directory.
5. Tags the image with both the Git commit SHA and `latest`.
6. Pushes both tags to Amazon ECR.
7. Forces a new deployment of the ECS service.
8. Waits for the ECS service to become stable before completing.

This removes the need to manually build and push images or restart the ECS service after application changes.

### Terraform Infrastructure Deployment

The Terraform workflow is stored in:

```text
.github/workflows/terraform.yml
```

It runs when infrastructure files under `infra/` change on the `main` branch, and it can also be started manually.

The workflow runs:

```text
terraform fmt -check -recursive
terraform init -input=false
terraform validate
terraform plan -input=false -out=tfplan
terraform apply -input=false -auto-approve tfplan
```

This means infrastructure changes are validated and planned before Terraform applies them to AWS.

### GitHub OIDC Authentication

Both workflows authenticate to AWS using GitHub OIDC instead of storing permanent AWS access keys as GitHub secrets.

I use separate IAM roles for the two workflows:

* The application deployment role has the permissions required to push images to ECR and update the ECS service.
* The Terraform role has the permissions required to manage the AWS infrastructure defined in Terraform.

Keeping these roles separate means the application deployment workflow does not need the wider infrastructure permissions required by Terraform.

The OIDC trust policies are restricted to the repository's `main` branch, so the roles cannot be assumed by unrelated repositories or branches.


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
cd ECS-Project
```

### 2. Build the Docker Image

From the root of the project:

```bash
docker build -t gatus ./app
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
docker build -t gatus ./app
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
cd ECS-Project
```

### 2. Test Gatus Locally

Before touching AWS, make sure the image works:

```bash
docker build -t gatus ./app
docker run --rm -p 8080:8080 gatus
```

Then:

```bash
curl http://localhost:8080/health
```
### 3. Create the Terraform Remote Backend

Terraform state for the main infrastructure is stored remotely in Amazon S3.

The backend resources are managed separately inside:

```text
infra/bootstrap/
```

For a first-time deployment, move into the bootstrap directory:

```bash
cd infra/bootstrap
```

Initialise Terraform:

```bash
terraform init
```

Review the resources that will be created:

```bash
terraform plan
```

Then create the S3 backend:

```bash
terraform apply
```

The backend bucket is configured with versioning, server-side encryption and public access blocking.

After the backend exists, return to the main Terraform directory:

```bash
cd ..
```

> The S3 backend bucket name must be globally unique. When reproducing this project in another AWS account, update the bucket name in the bootstrap configuration and the S3 backend configuration in `versions.tf`.

### 4. Configure Terraform Variables

Create:

```text
terraform.tfvars
```

inside the `infra/` directory and provide the values required by `variables.tf`.

I keep `terraform.tfvars` out of Git because it can contain environment-specific values and should not be committed to the public repository.

### 5. Initialise the Main Terraform Configuration

From inside `infra/`, run:

```bash
terraform init
```

Terraform will initialise the AWS provider, download the required modules and connect to the S3 remote backend.

### 6. Validate the Terraform

Check the formatting:

```bash
terraform fmt -check -recursive
```

Validate the configuration:

```bash
terraform validate
```

Then review the infrastructure changes:

```bash
terraform plan
```

I review the plan before applying it so I can confirm exactly what Terraform is going to create, update or remove.

### 7. Apply the Infrastructure

Apply the reviewed Terraform configuration:

```bash
terraform apply
```

Terraform provisions the networking, security, IAM, ACM certificate, Application Load Balancer, ECS resources, monitoring, DNS and GitHub OIDC configuration through the modules under `infra/modules/`.

### 8. Configure the GitHub Repository

The application deployment workflow uses these GitHub repository variables:

```text
AWS_REGION
AWS_ROLE_ARN
ECR_REPOSITORY
ECS_CLUSTER
ECS_SERVICE
CONTAINER_NAME
```

These identify the AWS region, GitHub Actions IAM role, ECR repository and ECS resources used by the application deployment pipeline.

There are two IAM roles used by GitHub Actions:

* an application deployment role for pushing images to ECR and updating ECS
* a Terraform role for managing the infrastructure

Both workflows use GitHub OIDC, so permanent AWS access keys do not need to be stored in GitHub.

### 9. Automated Deployments

There are two separate deployment workflows.

#### Application Changes

When application changes are pushed to `main`, `deploy.yml`:

```text
Authenticates to AWS using OIDC
        |
        v
Logs into Amazon ECR
        |
        v
Builds the image from app/
        |
        v
Tags it with the commit SHA + latest
        |
        v
Pushes both image tags to ECR
        |
        v
Triggers a new ECS deployment
        |
        v
Waits for the ECS service to become stable
```

#### Infrastructure Changes

When Terraform files under `infra/` change on `main`, `terraform.yml` runs:

```text
Terraform format check
        |
        v
Terraform init
        |
        v
Terraform validate
        |
        v
Terraform plan
        |
        v
Terraform apply
```

The Terraform workflow can also be started manually through GitHub Actions.


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

For a project like this, destroying infrastructure when I'm no longer using it is an important part of keeping the AWS bill under control.

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

### CI/CD Testing and Security Scanning

The project now has separate GitHub Actions workflows for application deployment and Terraform infrastructure changes.

The application pipeline does not currently include an automated test or container security scanning stage, and the Terraform pipeline does not yet include dedicated IaC security scanning.

These would be useful additions before treating the pipelines as production-ready.

---

## Future Improvements

There are a few things I'd like to add if I take the project further:

* Run more than one ECS task for better availability
* Add a NAT Gateway per Availability Zone
* Add automated application tests before deployment
* Scan Docker images for vulnerabilities
* Add Terraform security scanning
* Add CloudWatch alarms
* Add notifications for deployment or application failures
* Separate development and production environments
* Add an approval stage before Terraform applies infrastructure changes

These would improve the availability, security and deployment controls of the project without changing the core architecture I've already built.

---


## Keeping Local Files Out of Git

Terraform creates local working files, state files and variable files that shouldn't be committed to the repository.

My `.gitignore` excludes these recursively across the project:

```text
**/.terraform/
**/*.tfstate
**/*.tfstate.*
**/*.tfvars
**/*.tfvars.json
**/*.tfplan
```

Terraform state is especially important to keep out of a public repository because it can contain infrastructure details and potentially sensitive values.

I do commit the Terraform lock files:

```text
infra/.terraform.lock.hcl
infra/bootstrap/.terraform.lock.hcl
```

These keep the provider versions consistent between local development and GitHub Actions.

I also exclude environment files, AWS credentials, private keys, logs and local IDE files.

---


## What I Learned

The biggest takeaway from this project was understanding how all the individual AWS services fit together.

Before building it, it's easy to look at ECS, ALBs, target groups, NAT Gateways and route tables as separate AWS services. Working through the deployment made it much clearer how traffic actually moves between them.

The networking was probably the part I learned the most from. I had to understand why the ALB belongs in the public subnets, why the ECS task can stay private, and how the task can still get outbound internet access without having its own public IP.

Health checks were another useful lesson. A running ECS task doesn't automatically mean the application is working. Having both the container health check and ALB health check helped me see the difference.

Terraform also changed how I approached the infrastructure. I started with a flatter Terraform setup and then refactored it into reusable modules for areas like networking, security, ECS and the ALB. I also moved the state into an S3 remote backend, which helped me understand why state management matters when Terraform is being run from more than one place.

The CI/CD part brought everything together. I now have separate GitHub Actions workflows for application and infrastructure changes. One handles building the Docker image, pushing it to ECR and deploying to ECS, while the other validates, plans and applies Terraform changes. Both authenticate to AWS through OIDC instead of relying on permanent AWS access keys.

More than anything, this project helped me understand the full path from code running on my machine to a containerised application running privately in AWS and being served securely over a custom domain.

---

## Credits

Gatus is an open-source health monitoring project created by TwiN.

I used Gatus as the application for this project and built the Docker, AWS infrastructure, Terraform and CI/CD deployment around it.
