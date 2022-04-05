variable "name_prefix" {
  type    = string
  default = "flink-demo"
}

variable "cognito_user" {
  type    = string
  default = null
}

variable "cognito_password" {
  type    = string
  default = null
}