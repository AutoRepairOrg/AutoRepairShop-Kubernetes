variable "environment" {
  description = "Environment name"
  type        = string
  default     = "development"
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "oficina"
}
