variable "name_prefix" {
  type = string
}

variable "vpc_cidr" {
  description = "Deliberately not 10.0.0.0/16 — that's the most common default and the first thing to collide if this VPC is ever peered/connected to another."
  type        = string
  default     = "10.90.0.0/16"
}

variable "az_count" {
  description = "Number of AZs to spread the private subnets across."
  type        = number
  default     = 2
}

variable "tags" {
  type    = map(string)
  default = {}
}
