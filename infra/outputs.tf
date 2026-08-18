output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.autorepairshop.name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.autorepairshop.endpoint
}

output "eks_node_group" {
  description = "EKS node group"
  value       = aws_eks_node_group.autorepairshop.node_group_name
}

output "environment" {
  description = "Environment"
  value       = var.environment
}
