resource "aws_kinesis_stream" "this" {
  name             = "wildrydes"
  shard_count      = 1
  retention_period = 24
}

resource "aws_kinesis_stream" "summary" {
  name             = "wildrydes-summary"
  shard_count      = 1
  retention_period = 24
}

resource "aws_iam_role" "analytics" {
  name = "${var.name_prefix}-analytics-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "kinesisanalytics.amazonaws.com"
        }
      },
    ]
  })
  inline_policy {
    name = "policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid = "Kinesis"
          Action = [
            "*"
          ]
          Effect   = "Allow"
          Resource = "*"
        }
      ]
    })
  }
}

resource "aws_kinesis_analytics_application" "this" {
  name              = "wildrydes"
  start_application = true

  code = <<EOF
CREATE OR REPLACE STREAM "DESTINATION_SQL_STREAM" (
  "Name"                VARCHAR(16),
  "StatusTime"          TIMESTAMP,
  "Distance"            SMALLINT,
  "MinMagicPoints"      SMALLINT,
  "MaxMagicPoints"      SMALLINT,
  "MinHealthPoints"     SMALLINT,
  "MaxHealthPoints"     SMALLINT
);

CREATE OR REPLACE PUMP "STREAM_PUMP" AS
  INSERT INTO "DESTINATION_SQL_STREAM"
    SELECT STREAM "Name", "ROWTIME", SUM("Distance"), MIN("MagicPoints"),
                  MAX("MagicPoints"), MIN("HealthPoints"), MAX("HealthPoints")
    FROM "SOURCE_SQL_STREAM_001"
    GROUP BY FLOOR("SOURCE_SQL_STREAM_001"."ROWTIME" TO MINUTE), "Name";
EOF

  inputs {
    name_prefix = "SOURCE_SQL_STREAM"

    schema {
      record_columns {
        mapping  = "$.Distance"
        name     = "Distance"
        sql_type = "DOUBLE"
      }

      record_columns {
        mapping  = "$.HealthPoints"
        name     = "HealthPoints"
        sql_type = "INTEGER"
      }

      record_columns {
        mapping  = "$.Latitude"
        name     = "Latitude"
        sql_type = "DOUBLE"
      }

      record_columns {
        mapping  = "$.Longitude"
        name     = "Longitude"
        sql_type = "DOUBLE"
      }

      record_columns {
        mapping  = "$.MagicPoints"
        name     = "MagicPoints"
        sql_type = "INTEGER"
      }

      record_columns {
        mapping  = "$.Name"
        name     = "Name"
        sql_type = "VARCHAR(16)"
      }

      record_columns {
        mapping  = "$.StatusTime"
        name     = "StatusTime"
        sql_type = "TIMESTAMP"
      }

      //          record_encoding = "UTF-8"

      record_format {
        //            record_format_type = "JSON"

        mapping_parameters {
          json {
            record_row_path = "$"
          }
        }
      }
    }

    kinesis_stream {
      resource_arn = aws_kinesis_stream.this.arn
      role_arn     = aws_iam_role.analytics.arn
    }

    starting_position_configuration {
      starting_position = "NOW"
    }
  }

  outputs {
    name = "DESTINATION_SQL_STREAM"

    schema {
      record_format_type = "JSON"
    }

    kinesis_stream {
      resource_arn = aws_kinesis_stream.summary.arn
      role_arn     = aws_iam_role.analytics.arn
    }
  }
}

resource "aws_cognito_identity_pool" "this" {
  identity_pool_name               = "wildrydes"
  allow_unauthenticated_identities = true
}

resource "aws_iam_role" "unauthenticated" {
  name = "cognito_unauthenticated"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "cognito-identity.amazonaws.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "cognito-identity.amazonaws.com:aud": "${aws_cognito_identity_pool.this.id}"
        },
        "ForAnyValue:StringLike": {
          "cognito-identity.amazonaws.com:amr": "unauthenticated"
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "unauthenticated" {
  name = "unauthenticated_policy"
  role = aws_iam_role.unauthenticated.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "kinesis:*"
      ],
      "Resource": "${aws_kinesis_stream.this.arn}"
    },
  {
      "Effect": "Allow",
      "Action": [
        "kinesis:ListStreams"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_cognito_identity_pool_roles_attachment" "this" {
  identity_pool_id = aws_cognito_identity_pool.this.id
  roles = {
    //    "authenticated"   = aws_iam_role.authenticated.arn
    "unauthenticated" = aws_iam_role.unauthenticated.arn
  }
}

resource "aws_dynamodb_table" "this" {
  name           = "UnicornSensorData"
  billing_mode   = "PROVISIONED"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "Name"
  range_key      = "StatusTime"

  attribute {
    name = "Name"
    type = "S"
  }

  attribute {
    name = "StatusTime"
    type = "S"
  }

}

resource "aws_iam_role" "lambda" {
  name = "${var.name_prefix}-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
  inline_policy {
    name = "policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid = "all"
          Action = [
            "*"
          ]
          Effect   = "Allow"
          Resource = "*"
        }
      ]
    })
  }
}

resource "aws_lambda_function" "this" {
  filename      = "assets/lambda_function_payload.zip"
  function_name = "WildRydesStreamProcessor"
  role          = aws_iam_role.lambda.arn
  handler       = "index.handler"
  timeout = 60
  source_code_hash = filebase64sha256("assets/lambda_function_payload.zip")

  runtime = "nodejs12.x"

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.this.name
    }
  }
}

resource "aws_lambda_permission" "kinesis" {
  statement_id  = "AllowExecutionFromKinesis"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "kinesis.amazonaws.com"
  source_arn    = aws_kinesis_stream.summary.arn
}

resource "aws_lambda_event_source_mapping" "this" {
  event_source_arn  = aws_kinesis_stream.summary.arn
  function_name     = aws_lambda_function.this.arn
  starting_position = "LATEST"
}

resource "random_pet" "this" {}

resource "aws_s3_bucket" "this" {
  bucket        = "${var.name_prefix}-${random_pet.this.id}-bucket"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role" "firehose" {
  name = "${var.name_prefix}-firehose-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "firehose.amazonaws.com"
        }
      },
    ]
  })
  inline_policy {
    name = "policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid = "Kinesis"
          Action = [
            "*"
          ]
          Effect   = "Allow"
          Resource = "*"
        }
      ]
    })
  }
}

resource "aws_kinesis_firehose_delivery_stream" "this" {
  name        = "wildrydes"
  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.this.arn
    role_arn = aws_iam_role.firehose.arn
  }
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose.arn
    bucket_arn = aws_s3_bucket.this.arn
  }
}