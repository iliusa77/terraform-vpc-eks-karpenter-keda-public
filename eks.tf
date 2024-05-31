
module "eks" {
  source                          = "terraform-aws-modules/eks/aws"
  version                         = "~> 19.18"
  cluster_name                    = "${var.project}-cluster"
  cluster_version                 = "1.30"
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  enable_irsa                     = true
  vpc_id                          = module.vpc.vpc_id 
  subnet_ids                      = module.vpc.private_subnets
  control_plane_subnet_ids        = module.vpc.private_subnets


  cluster_addons = {
    coredns = {
      most_recent                 = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
    kube-proxy = {
      most_recent                 = true
      resolve_conflicts_on_create = true
      resolve_conflicts_on_update = true
    }
    vpc-cni = {
      most_recent                 = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }

    eks-pod-identity-agent = {
      most_recent                 = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"     
    }
  }

  eks_managed_node_groups = {
    karpenter = {
      instance_types = ["t2.medium","t2.small"]
      capacity_type = "SPOT"

      min_size     = 1
      max_size     = 100
      desired_size = 1

      use_custom_launch_template = false
      ami_type = "BOTTLEROCKET_x86_64"
      platform = "bottlerocket"
      bootstrap_extra_args = <<-EOT
        # extra args added
        [settings.kernel]
        lockdown = "integrity"
      EOT

      taints = {
        # This Taint aims to keep just EKS Addons and Karpenter running on this MNG
        # The pods that do not tolerate this taint should run on nodes created by Karpenter
        addons = {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }
    }
  }

  # EKS Managed Node Group(s)
  # eks_managed_node_group_defaults = {
  #   instance_types = ["t2.micro", "t2.small"]
  # }

  # eks_managed_node_groups = {
  #   workloads = {
  #     min_size     = 1
  #     max_size     = 3
  #     desired_size = 2

  #     instance_types = ["t2.small"]
  #     capacity_type  = "SPOT"

  #     use_custom_launch_template = false
  #     ami_type = "BOTTLEROCKET_x86_64"
  #     platform = "bottlerocket"
  #     bootstrap_extra_args = <<-EOT
  #       # extra args added
  #       [settings.kernel]
  #       lockdown = "integrity"
  #     EOT
  #   }
  # }

  # aws-auth configmap
  manage_aws_auth_configmap = true

  aws_auth_roles = [
    {
      rolearn  = "${aws_iam_role.cluster_role.arn}"
      username = "${aws_iam_role.cluster_role.name}"
      groups   = ["system:masters"]
    },
  ]

  aws_auth_users = [
    {
      userarn  = "arn:aws:iam::${var.aws_account}:user/${var.aws_user}"
      username = "${var.aws_user}"
      groups   = ["system:masters", "system:bootstrappers", "system:nodes"]
    },
  ]

  aws_auth_accounts = [
    data.aws_caller_identity.current.account_id,
  ]

  # Extend cluster security group rules
  cluster_security_group_additional_rules = {
    egress_nodes_ephemeral_ports_tcp = {
      description                = "To node 1025-65535"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "egress"
      source_node_security_group = true
    }
  }

  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    ingress_dns_udp_from_eni = {
      description              = "Eni To Node UDP DNS"
      protocol                 = "udp"
      from_port                = 53
      to_port                  = 53
      type                     = "ingress"
      cidr_blocks              = ["0.0.0.0/0"]
      ipv6_cidr_blocks         = ["::/0"]
    }
    ingress_istio_control_plane_ca_services = {
      description              = "Allow Cluster to istio control place CA services"
      protocol                 = "tcp"
      from_port                = 15012
      to_port                  = 15012
      type                     = "ingress"
      cidr_blocks              = ["0.0.0.0/0"]
      ipv6_cidr_blocks         = ["::/0"]
    }
    ingress_istio_webhook_port = {
      description              = "Allow Cluster to istio control place CA services"
      protocol                 = "tcp"
      from_port                = 15017
      to_port                  = 15017
      type                     = "ingress"
      cidr_blocks              = ["0.0.0.0/0"]
      ipv6_cidr_blocks         = ["::/0"]
    }
    ingress_http_port = {
      description              = "HTTP"
      protocol                 = "tcp"
      from_port                = 80
      to_port                  = 80
      type                     = "ingress"
      cidr_blocks              = ["0.0.0.0/0"]
      ipv6_cidr_blocks         = ["::/0"]
    }
    ingress_https_port = {
      description              = "HTTPS"
      protocol                 = "tcp"
      from_port                = 443
      to_port                  = 443
      type                     = "ingress"
      cidr_blocks              = ["0.0.0.0/0"]
      ipv6_cidr_blocks         = ["::/0"]
    }
  }

    node_security_group_tags = {
      "karpenter.sh/discovery" = "${var.project}-cluster"
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}