variable "project" {
  type        = string
  description = "Project Name"
}

variable "region" {
  type        = string
  default     = "eu-west-2"
}

variable "vpc_cidr_block" {
  type        = string
  description = "VPC CIDR"
}

variable "subnet_public_cidr_block" {
  type        = string
  description = "Public subnet CIDR"
}

variable "subnet_private_cidr_block" {
  type        = string
  description = "Private subnet CIDR"
}
