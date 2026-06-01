output "cluster_role_name" {
  value = aws_iam_role.eks_cluster_role.name
}

output "cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}

output "node_role_name" {
  value = aws_iam_role.eks_nodegroup_role.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
}