terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.2.0"
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

  force_destroy = true
}

resource "aws_s3_bucket_acl" "lambda_bucket" {
  bucket = aws_s3_bucket.lambda_bucket.id
  acl    = "private"
}
#####################
# lambda signup     #
#####################

data "archive_file" "lambda_signup" {
  type = "zip"

  source_dir  = "${path.module}/build/signup"
  output_path = "${path.module}/signup.zip"
}

resource "aws_s3_object" "lambda_signup" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "signup.zip"
  source = data.archive_file.lambda_signup.output_path

  etag = filemd5(data.archive_file.lambda_signup.output_path)
  tags = local.common_tags
}

resource "aws_lambda_function" "signup" {
  function_name = "signup"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_signup.key

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
      CONTACTS_TABLE_NAME    = aws_dynamodb_table.phoneBookTable.name
    }
  }

}


resource "aws_cloudwatch_log_group" "signup" {
  name = "/aws/lambda/${aws_lambda_function.signup.function_name}"

  retention_in_days = 30
  tags              = local.common_tags
}


resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_policy"
  role = aws_iam_role.lambda_exec.id

  policy = templatefile("policy.json.tpl", { dynamo_arn = aws_dynamodb_table.phoneBookTable.arn })

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
    audience = [aws_cognito_user_pool_client.phone_book_user_pool_client.id]
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

  route_key = "POST /accounts"
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

resource "aws_s3_object" "lambda_signin" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "signin.zip"
  source = data.archive_file.lambda_signin.output_path

  etag = filemd5(data.archive_file.lambda_signin.output_path)
  tags = local.common_tags
}

resource "aws_lambda_function" "signin" {
  function_name = "signin"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_signin.key

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

########################
# lambda createContact #
########################


data "archive_file" "lambda_createContact" {
  type = "zip"

  source_dir  = "${path.module}/build/createContact"
  output_path = "${path.module}/createContact.zip"
}

resource "aws_s3_object" "lambda_createContact" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "createContact.zip"
  source = data.archive_file.lambda_createContact.output_path

  etag = filemd5(data.archive_file.lambda_createContact.output_path)
  tags = local.common_tags
}

resource "aws_lambda_function" "createContact" {
  function_name = "createContact"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_createContact.key

  runtime = "nodejs14.x"
  handler = "createContact.handler"

  source_code_hash = data.archive_file.lambda_createContact.output_base64sha256

  role = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
      CONTACTS_TABLE_NAME = aws_dynamodb_table.phoneBookTable.name
    }
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "createContact" {
  name = "/aws/lambda/${aws_lambda_function.createContact.function_name}"

  retention_in_days = 30
  tags              = local.common_tags
}

resource "aws_apigatewayv2_integration" "createContact" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.createContact.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"

}

resource "aws_apigatewayv2_route" "createContact" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "POST /contacts"
  target    = "integrations/${aws_apigatewayv2_integration.createContact.id}"

  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.lambda.id

}

resource "aws_lambda_permission" "api_gw_createContact" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.createContact.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}


########################
# lambda getContact #
########################


data "archive_file" "lambda_getContact" {
  type = "zip"

  source_dir  = "${path.module}/build/getContact"
  output_path = "${path.module}/getContact.zip"
}

resource "aws_s3_object" "lambda_getContact" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "getContact.zip"
  source = data.archive_file.lambda_getContact.output_path

  etag = filemd5(data.archive_file.lambda_getContact.output_path)
  tags = local.common_tags
}

resource "aws_lambda_function" "getContact" {
  function_name = "getContact"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_getContact.key

  runtime = "nodejs14.x"
  handler = "getContact.handler"

  source_code_hash = data.archive_file.lambda_getContact.output_base64sha256

  role = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
      CONTACTS_TABLE_NAME = aws_dynamodb_table.phoneBookTable.name
    }
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "getContact" {
  name = "/aws/lambda/${aws_lambda_function.getContact.function_name}"

  retention_in_days = 30
  tags              = local.common_tags
}

resource "aws_apigatewayv2_integration" "getContact" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.getContact.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"

}

resource "aws_apigatewayv2_route" "getContact" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "GET /contacts"
  target    = "integrations/${aws_apigatewayv2_integration.getContact.id}"

  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.lambda.id

}


resource "aws_apigatewayv2_route" "getContactPath" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "GET /contacts/{name}"
  target    = "integrations/${aws_apigatewayv2_integration.getContact.id}"

  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.lambda.id

}

resource "aws_lambda_permission" "api_gw_getContact" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.getContact.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}


########################
# lambda deleteContact #
########################


data "archive_file" "lambda_deleteContact" {
  type = "zip"

  source_dir  = "${path.module}/build/deleteContact"
  output_path = "${path.module}/deleteContact.zip"
}

resource "aws_s3_object" "lambda_deleteContact" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "deleteContact.zip"
  source = data.archive_file.lambda_deleteContact.output_path

  etag = filemd5(data.archive_file.lambda_deleteContact.output_path)
  tags = local.common_tags
}

resource "aws_lambda_function" "deleteContact" {
  function_name = "deleteContact"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_deleteContact.key

  runtime = "nodejs14.x"
  handler = "deleteContact.handler"

  source_code_hash = data.archive_file.lambda_deleteContact.output_base64sha256

  role = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
      CONTACTS_TABLE_NAME = aws_dynamodb_table.phoneBookTable.name
    }
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "deleteContact" {
  name = "/aws/lambda/${aws_lambda_function.deleteContact.function_name}"

  retention_in_days = 30
  tags              = local.common_tags
}

resource "aws_apigatewayv2_integration" "deleteContact" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.deleteContact.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"

}

resource "aws_apigatewayv2_route" "deleteContact" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "DELETE /contacts"
  target    = "integrations/${aws_apigatewayv2_integration.deleteContact.id}"

  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.lambda.id

}


resource "aws_apigatewayv2_route" "deleteContactPath" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "DELETE /contacts/{name}"
  target    = "integrations/${aws_apigatewayv2_integration.deleteContact.id}"

  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.lambda.id

}

resource "aws_lambda_permission" "api_gw_deleteContact" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.deleteContact.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

########################
# lambda deleteAccount #
########################


data "archive_file" "lambda_deleteAccount" {
  type = "zip"

  source_dir  = "${path.module}/build/deleteAccount"
  output_path = "${path.module}/deleteAccount.zip"
}

resource "aws_s3_object" "lambda_deleteAccount" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "deleteAccount.zip"
  source = data.archive_file.lambda_deleteAccount.output_path

  etag = filemd5(data.archive_file.lambda_deleteAccount.output_path)
  tags = local.common_tags
}

resource "aws_lambda_function" "deleteAccount" {
  function_name = "deleteAccount"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_deleteAccount.key

  runtime = "nodejs14.x"
  handler = "deleteAccount.handler"
  timeout = 20

  source_code_hash = data.archive_file.lambda_deleteAccount.output_base64sha256

  role = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
      COGNITO_USER_POOL_ID   = aws_cognito_user_pool.phone_book_user_pool.id
      COGNITO_POOL_CLIENT_ID = aws_cognito_user_pool_client.phone_book_user_pool_client.id
      REGION                 = var.aws_region
      CONTACTS_TABLE_NAME    = aws_dynamodb_table.phoneBookTable.name
    }
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "deleteAccount" {
  name = "/aws/lambda/${aws_lambda_function.deleteAccount.function_name}"

  retention_in_days = 30
  tags              = local.common_tags
}

resource "aws_apigatewayv2_integration" "deleteAccount" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.deleteAccount.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"

}

resource "aws_apigatewayv2_route" "deleteAccount" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "DELETE /accounts"
  target    = "integrations/${aws_apigatewayv2_integration.deleteAccount.id}"

  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.lambda.id

}



resource "aws_lambda_permission" "api_gw_deleteAccount" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.deleteAccount.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

########################
# lambda preSignUp #
########################


data "archive_file" "lambda_preSignUp" {
  type = "zip"

  source_dir  = "${path.module}/build/preSignUp"
  output_path = "${path.module}/preSignUp.zip"
}

resource "aws_s3_object" "lambda_preSignUp" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "preSignUp.zip"
  source = data.archive_file.lambda_preSignUp.output_path

  etag = filemd5(data.archive_file.lambda_preSignUp.output_path)
  tags = local.common_tags
}

resource "aws_lambda_function" "preSignUp" {
  function_name = "preSignUp"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_preSignUp.key

  runtime = "nodejs14.x"
  handler = "preSignUp.handler"
  timeout = 20

  source_code_hash = data.archive_file.lambda_preSignUp.output_base64sha256

  role = aws_iam_role.lambda_exec.arn

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "preSignUp" {
  name = "/aws/lambda/${aws_lambda_function.preSignUp.function_name}"

  retention_in_days = 30
  tags              = local.common_tags
}

resource "aws_lambda_permission" "signUp" {
  statement_id  = "AllowExecutionFromCognito"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.preSignUp.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.phone_book_user_pool.arn
}


