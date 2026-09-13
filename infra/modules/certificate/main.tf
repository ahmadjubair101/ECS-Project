resource "aws_acm_certificate" "gatus" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  tags = {
    Name = "${var.project_name}-certificate"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.gatus.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

resource "aws_acm_certificate_validation" "gatus" {
  certificate_arn = aws_acm_certificate.gatus.arn

  validation_record_fqdns = [
    for record in aws_route53_record.acm_validation : record.fqdn
  ]
}
