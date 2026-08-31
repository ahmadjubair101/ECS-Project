data "aws_route53_zone" "gatus" {
  name         = var.domain_name
  private_zone = false
}

resource "aws_route53_record" "gatus" {
  zone_id = data.aws_route53_zone.gatus.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.gatus.dns_name
    zone_id                = aws_lb.gatus.zone_id
    evaluate_target_health = true
  }
}
