resource "aws_kinesis_stream" "this" {
  name             = "${var.name_prefix}-stream"
  shard_count      = 1
  retention_period = 24
}

resource "aws_iam_role" "this" {
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
          Sid = "ReadInputKinesis"
          Action = [
            "kinesis:DescribeStream",
            "kinesis:GetShardIterator",
            "kinesis:GetRecords",
            "kinesis:ListShards"
          ]
          Effect   = "Allow"
          Resource = aws_kinesis_stream.this.arn
        },
        {
          Sid = "Logs"
          Action = [
            "logs:*"
          ]
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Sid = "WriteObjects"
          Action = [
            "s3:*"
          ]
          Effect = "Allow"
          Resource = [
            aws_s3_bucket.results.arn,
            "${aws_s3_bucket.results.arn}/*",
            aws_s3_bucket.code.arn,
            "${aws_s3_bucket.code.arn}/*"
          ]
        },
      ]
    })
  }
}

resource "aws_kinesisanalyticsv2_application" "this" {
  depends_on             = [aws_s3_bucket_object.jar]
  name                   = "${var.name_prefix}-analytics"
  runtime_environment    = "FLINK-1_11"
  service_execution_role = aws_iam_role.this.arn
  start_application      = true
  application_configuration {
    application_code_configuration {
      code_content {
        s3_content_location {
          bucket_arn = aws_s3_bucket.code.arn
          file_key   = local.jar_target_file
        }
      }

      code_content_type = "ZIPFILE"
    }

    environment_properties {
      property_group {
        property_group_id = "ENVIRONMENT"
        property_map = {
          REGION       = data.aws_region.current.name
          INPUT_STREAM = aws_kinesis_stream.this.name
          BUCKET       = aws_s3_bucket.results.bucket
        }
      }
    }

    flink_application_configuration {
      checkpoint_configuration {
        configuration_type = "DEFAULT"
      }

      monitoring_configuration {
        configuration_type = "CUSTOM"
        log_level          = "DEBUG"
        metrics_level      = "TASK"
      }
    }

  }

  cloudwatch_logging_options {
    log_stream_arn = aws_cloudwatch_log_stream.this.arn
  }
}

resource "aws_s3_bucket" "code" {
  bucket        = "${var.name_prefix}-code-bucket"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "code_public_access_block" {
  bucket                  = aws_s3_bucket.code.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "results" {
  bucket        = "${var.name_prefix}-results-bucket"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "results_public_access_block" {
  bucket                  = aws_s3_bucket.results.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "null_resource" "build_jar" {
  triggers = {
    code = sha1(file("${path.module}/templates/S3Sink/src/main/java/com/amazonaws/services/kinesisanalytics/S3StreamingSinkJob.java"))
  }

  provisioner "local-exec" {
    command     = "mvn package -Dflink.version=1.11.1"
    working_dir = "${path.module}/templates/S3Sink"
  }
}

resource "aws_s3_bucket_object" "jar" {
  depends_on = [null_resource.build_jar]
  bucket     = aws_s3_bucket.code.bucket
  key        = "aws-kinesis-analytics-java-apps-1.0.jar"
  source     = "${path.module}/templates/S3Sink/target/${local.jar_target_file}"
  etag       = filemd5("${path.module}/templates/S3Sink/target/${local.jar_target_file}")
}


resource "aws_cloudwatch_log_group" "this" {
  name = "${var.name_prefix}-flink-log"
}

resource "aws_cloudwatch_log_stream" "this" {
  name           = "${var.name_prefix}-log-stream"
  log_group_name = aws_cloudwatch_log_group.this.name
}

resource "aws_cloudformation_stack" "this" {
  name         = "${var.name_prefix}-kinesis-generator"
  capabilities = ["CAPABILITY_IAM"]
  parameters = {
    Username = var.cognito_user
    Password = var.cognito_password
  }
  template_body = <<STACK
{
  "AWSTemplateFormatVersion" : "2010-09-09",
  "Description" : "This template creates an Amazon Cognito User Pool and Identity Pool, with a single user.  It assigns a role to authenticated users in the identity pool to enable the users to use the Kinesis Data Generator tool.",
  "Parameters" : {

    "Username": {
      "Description": "The username of the user you want to create in Amazon Cognito.",
      "Type": "String",
      "AllowedPattern": "^(?=\\s*\\S).*$",
      "ConstraintDescription": " cannot be empty"

    },
    "Password": {
      "Description": "The password of the user you want to create in Amazon Cognito.",
      "Type": "String",
      "NoEcho": true,
      "AllowedPattern": "^(?=.*[A-Za-z])(?=.*\\d)[A-Za-z\\d]{6,}$",
      "ConstraintDescription": " must be at least 6 alpha-numeric characters, and contain at least one number"
    }
  },
  "Metadata": {
    "AWS::CloudFormation::Interface": {
      "ParameterGroups": [
        {
          "Label": {
            "default": "Cognito User for Kinesis Data Generator"
          },
          "Parameters": [
            "Username",
            "Password"
          ]
        }
      ]
    }
  },
  "Resources" : {

    "DataGenCognitoSetupLambdaFunc" : {
      "Type" : "AWS::Lambda::Function",
      "Properties" : {
        "Code": {
          "S3Bucket" : {"Fn::Join": ["", [ "aws-kdg-tools-", {"Ref": "AWS::Region"}]]},
          "S3Key": "datagen-cognito-setup.zip"
        },
        "Description": "Creates a Cognito User Pool, Identity Pool, and a User.  Returns IDs to be used in the Kinesis Data Generator.",
        "FunctionName": "KinesisDataGeneratorCognitoSetup",
        "Handler": "createCognitoPool.createPoolAndUser",
        "Role": { "Fn::GetAtt" : ["LambdaExecutionRole", "Arn"] },
        "Runtime": "nodejs12.x",
        "Timeout": 60
      }
    },
    "LambdaExecutionRole": {
      "Type": "AWS::IAM::Role",
      "Properties": {
        "AssumeRolePolicyDocument": {
          "Version": "2012-10-17",
          "Statement": [{ "Effect": "Allow", "Principal": {"Service": ["lambda.amazonaws.com"]}, "Action": ["sts:AssumeRole"] }]
        },
        "Path": "/",
        "Policies": [{
          "PolicyName": "root",
          "PolicyDocument": {
            "Version": "2012-10-17",
            "Statement": [
              {
                "Effect": "Allow",
                "Action": [
                  "logs:CreateLogGroup",
                  "logs:CreateLogStream",
                  "logs:PutLogEvents"
                ],
                "Resource": [
                  "arn:aws:logs:*:*:log-group:/aws/lambda/KinesisDataGeneratorCognitoSetup*"
                ]
              },
              {
                "Effect": "Allow",
                "Action": [
                  "cognito-idp:AdminConfirmSignUp",
                  "cognito-idp:CreateUserPoolClient",
                  "cognito-idp:AdminCreateUser"
                ],
                "Resource": [
                  "arn:aws:cognito-idp:*:*:userpool/*"
                ]
              },
              {
                "Effect": "Allow",
                "Action": [
                  "cognito-idp:CreateUserPool",
                  "cognito-identity:CreateIdentityPool",
                  "cognito-identity:SetIdentityPoolRoles"
                ],
                "Resource": "*" },
              {
                "Effect": "Allow",
                "Action": ["iam:UpdateAssumeRolePolicy"],
                "Resource": [
                  {"Fn::GetAtt" : ["AuthenticatedUserRole", "Arn"] },
                  {"Fn::GetAtt" : ["UnauthenticatedUserRole", "Arn"] }
                ]
              },
              {
                "Effect": "Allow",
                "Action": ["iam:PassRole"],
                "Resource": [
                  {"Fn::GetAtt" : ["AuthenticatedUserRole", "Arn"] },
                  {"Fn::GetAtt" : ["UnauthenticatedUserRole", "Arn"] }
                ]
              }
            ]
          }
        }]
      }
    },
    "SetupCognitoCustom" : {
      "Type": "Custom::DataGenCognitoSetupLambdaFunc",
      "Properties": {
        "ServiceToken": { "Fn::GetAtt" : ["DataGenCognitoSetupLambdaFunc", "Arn"] },
        "Region": {"Ref": "AWS::Region"},
        "Username": {"Ref": "Username"},
        "Password": {"Ref": "Password"},
        "AuthRoleName": {"Ref": "AuthenticatedUserRole"},
        "AuthRoleArn": { "Fn::GetAtt" : ["AuthenticatedUserRole", "Arn"] },
        "UnauthRoleName": {"Ref": "UnauthenticatedUserRole"},
        "UnauthRoleArn": { "Fn::GetAtt" : ["UnauthenticatedUserRole", "Arn"] }

      }
    },
    "AuthenticatedUserRole": {
      "Type": "AWS::IAM::Role",
      "Properties": {
        "AssumeRolePolicyDocument": {
          "Version": "2012-10-17",
          "Statement": [{ "Effect": "Allow", "Principal": {"Federated": ["cognito-identity.amazonaws.com"]}, "Action": ["sts:AssumeRoleWithWebIdentity"] }]
        },
        "Path": "/",
        "Policies": [{
          "PolicyName": "root",
          "PolicyDocument": {
            "Version": "2012-10-17",
            "Statement": [
              {
                "Action": [
                  "kinesis:DescribeStream",
                  "kinesis:PutRecord",
                  "kinesis:PutRecords"
                ],
                "Resource": [
                  "arn:aws:kinesis:*:*:stream/*"
                ],
                "Effect": "Allow"
              },
              {
                "Action": [
                  "firehose:DescribeDeliveryStream",
                  "firehose:PutRecord",
                  "firehose:PutRecordBatch"
                ],
                "Resource": [
                  "arn:aws:firehose:*:*:deliverystream/*"
                ],
                "Effect": "Allow"
              },
              {
                "Action": [
                  "ec2:DescribeRegions",
                  "firehose:ListDeliveryStreams",
                  "kinesis:ListStreams"
                ],
                "Resource": [
                  "*"
                ],
                "Effect": "Allow"
              }
            ]
          }
        }]
      }
    },
    "UnauthenticatedUserRole": {
      "Type": "AWS::IAM::Role",
      "Properties": {
        "AssumeRolePolicyDocument": {
          "Version": "2012-10-17",
          "Statement": [{ "Effect": "Allow", "Principal": {"Federated": ["cognito-identity.amazonaws.com"]}, "Action": ["sts:AssumeRoleWithWebIdentity"] }]
        },
        "Path": "/",
        "Policies": [{
          "PolicyName": "root",
          "PolicyDocument": {
            "Version": "2012-10-17",
            "Statement": [
              {
                "Effect": "Deny",
                "Action": [
                  "*"
                ],
                "Resource": [
                  "*"
                ]
              }
            ]
          }
        }]
      }
    }
  },
  "Outputs":{
    "KinesisDataGeneratorUrl": {
      "Description": "The URL for your Kinesis Data Generator.",
      "Value": {
        "Fn::Join": ["", ["https://awslabs.github.io/amazon-kinesis-data-generator/web/producer.html?", { "Fn::GetAtt": [ "SetupCognitoCustom", "Querystring" ] }]]
      }
    }
  }

}
STACK
}