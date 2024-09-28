resource "kubernetes_namespace" "scheduler" {
  metadata {
    name = "scheduler"
  }
}

resource "kubernetes_cluster_role" "scheduler" {
  metadata {
    name = "scheduler"
  }
  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods/binding"]
    verbs      = ["create"]
  }
}

resource "kubernetes_cluster_role_binding" "scheduler" {
  metadata {
    name = "scheduler"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.scheduler.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.scheduler.metadata[0].name
    namespace = kubernetes_namespace.scheduler.metadata[0].name
  }
}

resource "kubernetes_service_account" "scheduler" {
  metadata {
    name      = "scheduler"
    namespace = kubernetes_namespace.scheduler.metadata[0].name
  }
}
