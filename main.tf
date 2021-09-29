variable "namespaces" {
  type = set(string)
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "<<TODO>>"
}

module "namespaces" {
  for_each = var.namespaces
  source   = "./namespace-module"
  name     = "${each.key}"
}

