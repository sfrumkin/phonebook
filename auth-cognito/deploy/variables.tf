# Input variable definitions

variable "aws_region" {
  description = "AWS region for all resources."

  type    = string
  default = "us-east-1"
}

variable "VPCname" {
  default = "sfrumkin"
}

variable "ApplicationName" {
  default = "sfrumkin"
}

variable "prefix" {
  default = "sf"
}