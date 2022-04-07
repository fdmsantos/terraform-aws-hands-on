variable "name_prefix" {
  type    = string
  default = "hadoop-demo"
}

variable "emr_release_label" {
  type    = string
  default = "emr-5.35.0"
}

variable "subnet_id" {
  type = string
}