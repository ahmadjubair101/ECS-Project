data "aws_route53_zone" "gatus" {
  name         = var.domain_name
  private_zone = false
}

