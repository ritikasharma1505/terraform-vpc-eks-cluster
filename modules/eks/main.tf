# =======================================================================================================
# EKS ROLE AND POLICY, EKSCLUSTER, EKS NODEGROUP ROLE AND POLICIES, EKS NODEGROUP, 
# EKS ADDONS, EKS-CLUSTER SG, TLS CERITIFCATE, OIDC PROVIDER, OIDC Assume Role Policy Document, IRSA Role
# =======================================================================================================

resource "aws_iam_role" "eks_cluster_role" {

  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "eks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role = aws_iam_role.eks_cluster_role.name
}


resource "aws_eks_cluster" "eks_cluster" {

  name     = var.cluster_name
  version = "1.35"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {

    subnet_ids = [var.private_subnet_1_id, var.private_subnet_2_id]
    security_group_ids = [aws_security_group.eks_cluster_sg.id]
    endpoint_private_access = true
    endpoint_public_access  = false       

  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]

  tags = {
    Name = var.cluster_name
  }
}

resource "aws_iam_role" "eks_nodegroup_role" {

  name = "eks-nodegroup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "worker_node_policy" {

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role = aws_iam_role.eks_nodegroup_role.name
}


resource "aws_iam_role_policy_attachment" "cni_policy" {

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role = aws_iam_role.eks_nodegroup_role.name
}


resource "aws_iam_role_policy_attachment" "ecr_policy" {

  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role = aws_iam_role.eks_nodegroup_role.name
}


resource "aws_eks_node_group" "private_nodes" {

  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "private-nodes"
  node_role_arn = aws_iam_role.eks_nodegroup_role.arn

  subnet_ids = [
    var.private_subnet_1_id,
    var.private_subnet_2_id
  ]

  capacity_type  = "ON_DEMAND"
  instance_types = ["t3.medium"]

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.worker_node_policy,
    aws_iam_role_policy_attachment.cni_policy,
    aws_iam_role_policy_attachment.ecr_policy,
    aws_iam_role_policy_attachment.ebs_csi_policy
  ]
}


resource "aws_security_group" "eks_cluster_sg" {

  name        = "eks-cluster-sg"
  description = "EKS Cluster Security Group"
  vpc_id      = var.vpc_id

  ingress {

    description = "Kubernetes API"

    from_port = 443
    to_port   = 443

    protocol = "tcp"

    cidr_blocks = [var.vpc_cidr]
  }

  egress {

    from_port = 0
    to_port   = 0

    protocol = "-1"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  tags = {
    Name = "eks-cluster-sg"
  }
}

resource "aws_eks_addon" "vpc_cni" {

  cluster_name = aws_eks_cluster.eks_cluster.name

  addon_name = "vpc-cni"

  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.private_nodes
  ]
}

resource "aws_eks_addon" "coredns" {

  cluster_name = aws_eks_cluster.eks_cluster.name

  addon_name = "coredns"

  addon_version = "v1.14.2-eksbuild.4"

  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.private_nodes
  ]
}

resource "aws_eks_addon" "kube_proxy" {

  cluster_name = aws_eks_cluster.eks_cluster.name

  addon_name = "kube-proxy"

  addon_version = "v1.35.3-eksbuild.5"

  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.private_nodes
  ]
}

resource "aws_eks_addon" "ebs_csi" {

  cluster_name = aws_eks_cluster.eks_cluster.name

  addon_name = "aws-ebs-csi-driver"

  service_account_role_arn = aws_iam_role.eks_oidc_role.arn

  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.private_nodes
  ]
}


data "tls_certificate" "eks_oidc_tls" {

  url = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}


resource "aws_iam_openid_connect_provider" "eks_oidc" {

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = [data.tls_certificate.eks_oidc_tls.certificates[0].sha1_fingerprint]

  url = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}


data "aws_iam_policy_document" "eks_oidc_assume_role_policy" {

  statement {

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    effect = "Allow"

    condition {
      test = "StringEquals"

      variable = "${replace(aws_iam_openid_connect_provider.eks_oidc.url, "https://", "")}:sub"

      values = [
        "system:serviceaccount:kube-system:ebs-csi-controller-sa"
      ]
    }

    principals {

      identifiers = [
        aws_iam_openid_connect_provider.eks_oidc.arn
      ]

      type = "Federated"
    }
  }
}


resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"

  role = aws_iam_role.eks_oidc_role.name
}

resource "aws_iam_role" "eks_oidc_role" {

  name = "eks-oidc-role"
  assume_role_policy = data.aws_iam_policy_document.eks_oidc_assume_role_policy.json
}