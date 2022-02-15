resource "aws_dynamodb_table" "phoneBookTable" {
  name           = "PhoneBook"
  billing_mode   = "PAY_PER_REQUEST"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "pk"
  range_key      = "sk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  global_secondary_index {
    name     = "SkIndex"
    hash_key = "sk"
    # range_key          = "pk"
    write_capacity     = 10
    read_capacity      = 10
    projection_type    = "INCLUDE"
    non_key_attributes = ["data"]
  }

  tags = local.common_tags
}