variable "name_prefix" {
  type    = string
  default = "warehouse-demo"
}

variable "domain" {
  type = string
  default = "example.com"
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}
variable "cloud9_sg_id" {
  type = string
}

variable "password" {
  type = string
}