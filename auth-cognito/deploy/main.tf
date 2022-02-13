terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.48.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }

  required_version = "~> 1.0"
}

provider "aws" {
  region = var.aws_region
}

locals {
  prefix = var.prefix
  common_tags = {
    ApplicationName = var.ApplicationName
    VPCname         = var.VPCname
  }
}
resource "random_pet" "lambda_bucket_name" {
  prefix = "contacts-sf"
  length = 4
}

#####################
# lambda generic    #
#####################

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = random_pet.lambda_bucket_name.id

  acl           = "private"
  force_destroy = true
}

#####################
# lambda signup     #
#####################

data "archive_file" "lambda_signup" {
  type = "zip"

  source_dir  = "${path.module}/build/signup"
  output_path = "${path.module}/signup.zip"
}

resource "aws_s3_bucket_object" "lambda_signup" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "signup.zip"
  source = data.archive_file.lambda_signup.output_path

  etag = filemd5(data.archive_file.lambda_signup.output_path)
  tags = local.common_tags
}

resource "aws_lambda_function" "signup" {
  function_name = "signup"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_bucket_object.lambda_signup.key

  runtime = "nodejs14.x"
  handler = "signup.handler"

  source_code_hash = data.archive_file.lambda_signup.output_base64sha256

  role = aws_iam_role.lambda_exec.arn

  tags = local.common_tags

  environment {
    variables = {
      COGNITO_USER_POOL_ID   = aws_cognito_user_pool.phone_book_user_pool.id
      COGNITO_POOL_CLIENT_ID = aws_cognito_user_pool_client.phone_book_user_pool_client.id
      REGION                 = var.aws_region
    }
  }
}


resource "aws_cloudwatch_log_group" "signup" {
  name = "/aws/lambda/${aws_lambda_function.signup.function_name}"

  retention_in_days = 30
  tags              = local.common_tags
}

resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_apigatewayv2_api" "lambda" {
  name          = "serverless_lambda_gw"
  protocol_type = "HTTP"

  tags = local.common_tags
}

resource "aws_apigatewayv2_authorizer" "lambda" {
  api_id           = aws_apigatewayv2_api.lambda.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "lambda-authorizer"

  jwt_configuration {
    audience = ["example"]
    issuer   = "https://${aws_cognito_user_pool.phone_book_user_pool.endpoint}"
  }
}
resource "aws_apigatewayv2_stage" "lambda" {
  api_id = aws_apigatewayv2_api.lambda.id

  name        = "serverless_lambda_stage"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
  tags = local.common_tags
}

resource "aws_apigatewayv2_integration" "signup" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.signup.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"

}

resource "aws_apigatewayv2_route" "signup" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "POST /signup"
  target    = "integrations/${aws_apigatewayv2_integration.signup.id}"

}

resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"

  retention_in_days = 30

  tags = local.common_tags
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.signup.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

#####################
# lambda signin     #
#####################

data "archive_file" "lambda_signin" {
  type = "zip"

  source_dir  = "${path.module}/build/signin"
  output_path = "${path.module}/signin.zip"
}

resource "aws_s3_bucket_object" "lambda_signin" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "signin.zip"
  source = data.archive_file.lambda_signin.output_path

  etag = filemd5(data.archive_file.lambda_signin.output_path)
  tags = local.common_tags
}

resource "aws_lambda_function" "signin" {
  function_name = "signin"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_bucket_object.lambda_signin.key

  runtime = "nodejs14.x"
  handler = "signin.handler"
  timeout = 20

  source_code_hash = data.archive_file.lambda_signin.output_base64sha256

  role = aws_iam_role.lambda_exec.arn

  tags = local.common_tags

  environment {
    variables = {
      COGNITO_USER_POOL_ID   = aws_cognito_user_pool.phone_book_user_pool.id
      COGNITO_POOL_CLIENT_ID = aws_cognito_user_pool_client.phone_book_user_pool_client.id
      REGION                 = var.aws_region
    }
  }
}


resource "aws_cloudwatch_log_group" "signin" {
  name = "/aws/lambda/${aws_lambda_function.signin.function_name}"

  retention_in_days = 30
  tags              = local.common_tags
}

resource "aws_apigatewayv2_integration" "signin" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.signin.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"

}

resource "aws_apigatewayv2_route" "signin" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "POST /signin"
  target    = "integrations/${aws_apigatewayv2_integration.signin.id}"

}

resource "aws_lambda_permission" "api_gw_signin" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.signin.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

