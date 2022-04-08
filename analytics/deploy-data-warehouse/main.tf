resource "aws_redshift_cluster" "example" {
  cluster_identifier = "${var.name_prefix}-redshift-cluster"
  database_name      = "demo"
  master_username    = var.redshift_user
  master_password    = var.redshift_password
  node_type          = "dc2.large"
  cluster_type       = "single-node"
  iam_roles = [aws_iam_role.this.arn]
  skip_final_snapshot = true
}

resource "aws_iam_role" "this" {
  name = "${var.name_prefix}-role"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "redshift.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "this" {
  name = "${var.name_prefix}-servicerole-policy"
  role = aws_iam_role.this.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}
