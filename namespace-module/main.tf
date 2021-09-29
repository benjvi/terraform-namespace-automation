variable "name" {
  type = string
}

variable "namespace_cpu_req" {
  type = string
  default = "1"
}

variable "namespace_mem_req" {
  type = string
  default = "1Gi"
}

variable "container_default_req_mem" {
  type = string
  default = "100M"
}

variable "container_default_req_cpu" {
  type = string
  default = "100m"
}

resource "kubernetes_namespace" "ns" {
  metadata {
    labels = {
      name = var.name
    }

    name = var.name
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "kubernetes_resource_quota" "requests-guaranteed-resources" {
  metadata {
    name = "requests-guaranteed-resources"
    namespace = kubernetes_namespace.ns.id
  }
  spec {
    hard = {
      "requests.cpu" = var.namespace_cpu_req
      "requests.memory" = var.namespace_mem_req
    }
  }
}

resource "kubernetes_limit_range" "limitrange" {
  metadata {
    name = "default-container-requests"
    namespace = kubernetes_namespace.ns.id
  }
  spec {
    limit {
      type = "Container"
      default_request = {
        cpu    = var.container_default_req_cpu
        memory = var.container_default_req_mem
      }
    }
  }
}
