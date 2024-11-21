variable "name" {
  description = "Service name for resources"
  type        = string
  default     = "service"
}

variable "cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.83.0.0/16"
}

variable "azs" {
  description = "Availability zones"
  type        = list(string)
  default = [
    "us-east-1a",
    "us-east-1b"
  ]
}

variable "private_subnets" {
  description = "Private subnets for VPC"
  type        = list(string)
  default = [
    "10.83.1.0/24",
    "10.83.3.0/24"
  ]
}

variable "public_subnets" {
  description = "Public subnets for VPC"
  type        = list(string)
  default = [
    "10.83.0.0/24",
    "10.83.2.0/24"
  ]
}

variable "tags" {
  description = "Tags for resources"
  type        = map(string)
  default     = {}
}

variable "vpc_endpoint_tags" {
  description = "Tags for VPC endpoints"
  type        = map(string)
  default     = { endpoint = "true" }
}

variable "ingress_cidr_blocks" {
  description = "CIDR blocks allowed for ingress traffic"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ingress_rules" {
  description = "Ingress rules for the security group"
  type        = list(string)
  default     = ["all-all"]
}

variable "egress_cidr_blocks" {
  description = "CIDR blocks allowed for egress traffic"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "egress_rules" {
  description = "Egress rules for the security group"
  type        = list(string)
  default     = ["all-all"]
}

variable "ami_ssm_parameter" {
  description = "SSM Parameter for the desired AMI"
  type        = string
  default     = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

variable "ignore_ami_changes" {
  description = "Do not recreate instance on new AMI"
  type        = bool
  default     = true
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "enable_monitoring" {
  description = "Enable detailed monitoring for instances"
  type        = bool
  default     = true
}

variable "metadata_options" {
  description = "Configuration for EC2 instance metadata service options"
  type        = map(any)
  default = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    instance_metadata_tags      = "enabled"
    http_put_response_hop_limit = 3
  }
}

variable "keypair_enabled" {
  description = "Flag to enable or disable the creation of a key pair for instances"
  type        = bool
  default     = false
}

variable "bastion_enabled" {
  description = "Enable bastion instance"
  type        = bool
  default     = false
}

variable "vpc_endpoints_enabled" {
  description = "Enable VPC endpoints"
  type        = bool
  default     = false
}

variable "bastion_private_ip" {
  description = "Defines what private IP address will be used by the bastion instance"
  type        = string
  default     = null
}

variable "service_private_ip" {
  description = "Defines what private IP address will be used by the service instance"
  type        = string
  default     = null
}

variable "user_data" {
  description = "The configuration to bbotstrap the instance"
  type        = string
  default     = null
}

variable "user_data_replace_on_change" {
  description = "Flag to determine if the instance should be replaced when user_data changes"
  type        = bool
  default     = true
}
