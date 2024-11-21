module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.16.0"

  name = "${var.name}-vpc"

  cidr            = var.cidr
  azs             = var.azs
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  enable_dns_hostnames = true
  enable_nat_gateway   = true
  enable_dhcp_options  = true

  tags = var.tags
}

data "aws_iam_policy_document" "generic_endpoint" {
  statement {
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["*"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceVpc"
      values   = [module.vpc.vpc_id]
    }
    effect = "Allow"
  }

  statement {
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["*"]
    resources = ["*"]
    condition {
      test     = "StringNotEquals"
      variable = "aws:SourceVpc"
      values   = [module.vpc.vpc_id]
    }
    effect = "Deny"
  }
}

module "vpc_endpoints" {
  count = var.vpc_endpoints_enabled ? 1 : 0

  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "5.16.0"

  vpc_id = module.vpc.vpc_id

  endpoints = merge(
    {
      s3 = {
        service      = "s3"
        service_type = "Gateway"
        route_table_ids = flatten([
          module.vpc.private_route_table_ids,
          module.vpc.public_route_table_ids
        ])
        policy = data.aws_iam_policy_document.generic_endpoint.json
      }
    },
    {
      for service in toset(
        [
          "ec2messages",
          "ssm",
          "ssmmessages"
        ]
      ) :
      replace(service, ".", "_") =>
      {
        service             = service
        subnet_ids          = module.vpc.private_subnets
        private_dns_enabled = true
        dns_options = {
          private_dns_only_for_inbound_resolver_endpoint = false
        }
        tags = { Name = "${var.name}-${service}" }
      }
    }
  )

  create_security_group      = true
  security_group_name_prefix = "${var.name}-vpc-endpoints-"
  security_group_description = "VPC endpoint security group"
  security_group_rules = {
    ingress_https = {
      description = "HTTPS from subnets"
      cidr_blocks = flatten([
        module.vpc.private_subnets_cidr_blocks,
        module.vpc.public_subnets_cidr_blocks
      ])
    }
  }

  tags = var.tags
}

module "sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.2.0"

  name   = "${var.name}-sg"
  vpc_id = module.vpc.vpc_id

  ingress_cidr_blocks = var.ingress_cidr_blocks
  ingress_rules       = var.ingress_rules

  egress_cidr_blocks = var.egress_cidr_blocks
  egress_rules       = var.egress_rules

  tags = var.tags
}

module "key_pair" {
  count = var.keypair_enabled ? 1 : 0

  source  = "terraform-aws-modules/key-pair/aws"
  version = "2.0.3"

  key_name           = "${var.name}-keypair"
  create_private_key = true
}

module "bastion" {
  count = var.bastion_enabled ? 1 : 0

  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.7.1"

  name = "${var.name}-bastion"

  ami_ssm_parameter      = var.ami_ssm_parameter
  ignore_ami_changes     = var.ignore_ami_changes
  instance_type          = var.instance_type
  monitoring             = var.enable_monitoring
  metadata_options       = var.metadata_options
  vpc_security_group_ids = [module.sg.security_group_id]
  subnet_id              = module.vpc.public_subnets[0]
  private_ip             = try(var.bastion_private_ip, cidrhost(module.vpc.private_subnets_cidr_blocks[0], 22))
  key_name               = var.keypair_enabled ? module.key_pair[0].key_pair_name : null

  create_eip                  = true
  create_iam_instance_profile = true
  iam_role_description        = "IAM role for EC2 instance"
  iam_role_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    CloudWatchAgentServerPolicy  = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  }

  enable_volume_tags = false

  tags = var.tags
  instance_tags = merge(
    var.tags,
    {
      Role = "${var.name}-bastion"
      OS   = "al2023"
    }
  )
}

resource "aws_iam_policy" "service" {
  name        = "${var.name}-service"
  description = "Policy for ${var.name}-service instance with EC2 permissions"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRRead"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ],
        Resource = ["*"]
      },
      {
        Sid    = "DescribeTags"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeVolumes",
          "ec2:AttachVolume",
          "ec2:DescribeTags",
          "autoscaling:DescribeAutoScalingGroups"
        ]
        Resource = ["*"]
      }
    ]
  })
}

module "service" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.7.1"

  name = "${var.name}-service"

  ami_ssm_parameter      = var.ami_ssm_parameter
  ignore_ami_changes     = var.ignore_ami_changes
  instance_type          = var.instance_type
  monitoring             = var.enable_monitoring
  metadata_options       = var.metadata_options
  vpc_security_group_ids = [module.sg.security_group_id]
  subnet_id              = var.bastion_enabled ? module.vpc.private_subnets[0] : module.vpc.public_subnets[0]
  private_ip = try(var.service_private_ip,
    var.bastion_enabled ?
    cidrhost(module.vpc.private_subnets_cidr_blocks[0], 22) : cidrhost(module.vpc.public_subnets_cidr_blocks[0], 22)
  )
  key_name = var.keypair_enabled ? module.key_pair[0].key_pair_name : null

  create_eip                  = var.bastion_enabled ? false : true
  create_iam_instance_profile = true
  iam_role_description        = "IAM role for EC2 instance"
  iam_role_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    CloudWatchAgentServerPolicy  = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
    EC2Policy                    = aws_iam_policy.service.arn
  }

  enable_volume_tags = false

  user_data                   = var.user_data
  user_data_replace_on_change = var.user_data_replace_on_change

  tags = var.tags
  instance_tags = merge(
    var.tags,
    {
      Role = "${var.name}-service"
      OS   = "al2023"
    }
  )
}
