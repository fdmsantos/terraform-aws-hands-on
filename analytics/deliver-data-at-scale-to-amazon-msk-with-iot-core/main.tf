data "aws_partition" "current" {}
data "aws_region" "current" {}

resource "aws_acmpca_certificate_authority" "this" {
  type = "ROOT"
  certificate_authority_configuration {
    key_algorithm     = "RSA_4096"
    signing_algorithm = "SHA512WITHRSA"
    subject {
      common_name = var.domain
    }
  }
  permanent_deletion_time_in_days = 7
}

# Necessary because terraform doesn't support this resource
# Issue: https://github.com/hashicorp/terraform-provider-aws/issues/10090
# PR: https://github.com/hashicorp/terraform-provider-aws/pull/12485
resource "null_resource" "this" {
  depends_on = [aws_acmpca_certificate_authority.this]
  triggers = {
    certificate_arn = aws_acmpca_certificate_authority.this.arn
  }
  provisioner "local-exec" {
      command = "aws acm-pca create-permission --certificate-authority-arn ${aws_acmpca_certificate_authority.this.arn} --principal acm.amazonaws.com --actions IssueCertificate GetCertificate  ListPermissions"
  }
}

resource "aws_acmpca_certificate" "this" {
  certificate_authority_arn   = aws_acmpca_certificate_authority.this.arn
  certificate_signing_request = aws_acmpca_certificate_authority.this.certificate_signing_request
  signing_algorithm           = "SHA512WITHRSA"
  template_arn = "arn:${data.aws_partition.current.partition}:acm-pca:::template/RootCACertificate/V1"
  validity {
    type  = "YEARS"
    value = 1
  }
}

resource "aws_acmpca_certificate_authority_certificate" "example" {
  certificate_authority_arn = aws_acmpca_certificate_authority.this.arn
  certificate       = aws_acmpca_certificate.this.certificate
  certificate_chain = aws_acmpca_certificate.this.certificate_chain
}

module "kafka" {
  source = "cloudposse/msk-apache-kafka-cluster/aws"
  version = "0.8.4"
  namespace              = "eg"
  stage                  = "dev"
  name                   = "${var.name_prefix}-kafka"
  vpc_id                 = var.vpc_id
  subnet_ids             = var.subnet_ids
  kafka_version          = "2.6.1"
  number_of_broker_nodes = 2
  broker_instance_type   = "kafka.t3.small"

  certificate_authority_arns = [aws_acmpca_certificate_authority.this.arn]
  create_security_group = true

  # security groups to put on the cluster itself
 // associated_security_group_ids = [ var.sg ]
  # security groups to give access to the cluster
  allowed_security_group_ids = [ var.cloud9_sg_id ]
}

data "template_file" "config" {
  template = file("${path.module}/templates/commands.sh")
  vars = {
    CLUSTER_ARN = module.kafka.cluster_arn
    PRIVATE_CA_ARN = aws_acmpca_certificate_authority.this.arn
    AWS_REGION = data.aws_region.current.name
    PASSWORD = var.password
  }
}