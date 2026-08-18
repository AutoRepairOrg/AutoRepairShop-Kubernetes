data "aws_iam_role" "lab" {
  name = "LabRole"
}

resource "aws_eks_cluster" "autorepairshop" {
  name     = "autorepairshop-eks"
  role_arn = data.aws_iam_role.lab.arn
  version  = "1.31"

  vpc_config {
    subnet_ids = [
      "subnet-07d988ad8c5e3a697",
      "subnet-0fc6ceff22ca1c5eb"
    ]

    endpoint_public_access  = true
    endpoint_private_access = false
  }
}

resource "aws_eks_node_group" "autorepairshop" {
  cluster_name    = aws_eks_cluster.autorepairshop.name
  node_group_name = "autorepairshop-nodes"
  node_role_arn   = data.aws_iam_role.lab.arn

  subnet_ids = [
    "subnet-07d988ad8c5e3a697",
    "subnet-0fc6ceff22ca1c5eb"
  ]

  instance_types = ["t3.small"]

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 2
  }

  depends_on = [
    aws_eks_cluster.autorepairshop
  ]
}
