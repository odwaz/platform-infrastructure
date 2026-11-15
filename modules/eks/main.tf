module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.name
  kubernetes_version = var.kubernetes_version

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  endpoint_public_access       = true
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs

  # Pods get IAM roles through EKS Pod Identity, so the cluster needs no IRSA OIDC provider. Without it, the
  # Terraform Cloud role needs no permission over OIDC providers.
  enable_irsa = false

  # The identity that runs the apply (the Terraform Cloud role) is admin...
  enable_cluster_creator_admin_permissions = true

  # ...and so are you, so kubectl works from your machine.
  access_entries = {
    admin = {
      principal_arn = var.admin_principal_arn
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
    # Gives pods IAM roles through EKS Pod Identity, without an OIDC provider per cluster.
    eks-pod-identity-agent = {
      before_compute = true
    }
    # Creates EBS volumes for PersistentVolumeClaims. Its controller gets the role below through Pod Identity.
    aws-ebs-csi-driver = {
      pod_identity_association = [{
        role_arn        = aws_iam_role.ebs_csi.arn
        service_account = "ebs-csi-controller-sa"
      }]
    }
  }

  eks_managed_node_groups = {
    main = {
      # Amazon Linux 2 node images are not published after Kubernetes 1.32.
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.instance_types
      capacity_type  = "ON_DEMAND"

      # <name>-node-*, like every other IAM name in the stack, so the Terraform Cloud role can be limited to the
      # stack's own names. The module's default, main-eks-node-group-*, is the same in every stack.
      iam_role_name = "${var.name}-node"

      min_size     = var.min_size
      max_size     = var.max_size
      desired_size = var.desired_size
    }
  }
}

# The EBS CSI controller's role. It trusts the EKS Pod Identity service; the add-on above binds it to the
# controller's service account, so only that pod receives these permissions.
data "aws_iam_policy_document" "ebs_csi_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${var.name}-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
