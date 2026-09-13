module "networking" {
  source = "./modules/networking"

  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr

}

module "security" {
  source = "./modules/security"

  project_name   = var.project_name
  vpc_id         = module.networking.vpc_id
  container_port = var.container_port
}

module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
}

module "monitoring" {
  source = "./modules/monitoring"

  project_name = var.project_name
}

module "certificate" {
  source = "./modules/certificate"

  project_name    = var.project_name
  domain_name     = var.domain_name
  route53_zone_id = data.aws_route53_zone.gatus.zone_id
}

module "alb" {
  source = "./modules/alb"

  project_name          = var.project_name
  container_port        = var.container_port
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  alb_security_group_id = module.security.alb_security_group_id
  certificate_arn       = module.certificate.certificate_arn
}

module "dns" {
  source = "./modules/dns"

  domain_name     = var.domain_name
  route53_zone_id = data.aws_route53_zone.gatus.zone_id
  alb_dns_name    = module.alb.alb_dns_name
  alb_zone_id     = module.alb.alb_zone_id
}

module "ecs" {
  source = "./modules/ecs"

  project_name                = var.project_name
  aws_region                  = var.aws_region
  container_port              = var.container_port
  container_cpu               = var.container_cpu
  container_memory            = var.container_memory
  ecr_repository_url          = var.ecr_repository_url
  ecs_task_execution_role_arn = module.iam.ecs_task_execution_role_arn
  log_group_name              = module.monitoring.log_group_name
  private_subnet_ids          = module.networking.private_subnet_ids
  ecs_security_group_id       = module.security.ecs_security_group_id
  target_group_arn            = module.alb.target_group_arn
}

module "github_oidc" {
  source = "./modules/github-oidc"

  github_oidc_subject = "repo:ahmadjubair101@289809123/ECS-Project@1345149016:ref:refs/heads/main"
}

module "terraform_ci" {
  source = "./modules/terraform-ci"

  oidc_provider_arn = module.github_oidc.oidc_provider_arn

  github_oidc_subject = "repo:ahmadjubair101@289809123/ECS-Project@1345149016:ref:refs/heads/main"
}
