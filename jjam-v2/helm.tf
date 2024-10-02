provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

resource "kubernetes_namespace" "scheduler_plugins" {
  metadata {
    name = "scheduler-plugins"
  }
}



resource "helm_release" "scheduler" {
  depends_on = [kubernetes_namespace.scheduler_plugins]
  name       = "scheduler-plugins"
  repository = "https://scheduler-plugins.sigs.k8s.io"
  chart      = "scheduler-plugins"
  namespace  = kubernetes_namespace.scheduler_plugins.metadata[0].name

}
