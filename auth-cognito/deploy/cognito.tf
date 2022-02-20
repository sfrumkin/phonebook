resource "aws_cognito_user_pool" "phone_book_user_pool" {
  name = "phoneBookUserPool"

  alias_attributes         = ["email"]
  auto_verified_attributes = ["email"]

  lambda_config {
    pre_sign_up = aws_lambda_function.preSignUp.arn
  }

  verification_message_template {
    default_email_option  = "CONFIRM_WITH_LINK"
    email_message_by_link = "Please use the following link to confirm: {##Click Here##}"
    email_subject_by_link = "Please confirm your email address"
  }

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  username_configuration {
    case_sensitive = false
  }

  schema {
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    name                     = "email"
    required                 = true

    string_attribute_constraints {
      min_length = 7
      max_length = 256
    }
  }



}

resource "aws_cognito_user_pool_client" "phone_book_user_pool_client" {
  name                = "phoneBookUserPoolClient"
  explicit_auth_flows = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH", "ALLOW_USER_SRP_AUTH"]

  user_pool_id = aws_cognito_user_pool.phone_book_user_pool.id
}

resource "aws_cognito_user_pool_domain" "phone_book" {
  domain       = "phonebook-domain"
  user_pool_id = aws_cognito_user_pool.phone_book_user_pool.id
}
