# Custom Resource Definition (CRD) for NetworkMetrics
resource "kubernetes_manifest" "network_metrics_crd" {
  manifest = {
    apiVersion = "apiextensions.k8s.io/v1"
    kind       = "CustomResourceDefinition"
    metadata = {
      name = "networkmetrics.network.example.com"
    }
    spec = {
      group = "network.example.com"
      versions = [{
        name    = "v1"
        served  = true
        storage = true
        schema = {
          openAPIV3Schema = {
            type = "object"
            properties = {
              spec = {
                type = "object"
                properties = {
                  metrics = {
                    type                                 = "object"
                    x-kubernetes-preserve-unknown-fields = true
                  }
                }
              }
            }
          }
        }
      }]
      scope = "Namespaced"
      names = {
        plural     = "networkmetrics"
        singular   = "networkmetric"
        kind       = "NetworkMetrics"
        shortNames = ["nm"]
      }
    }
  }
}

# Service Account for the master
resource "kubernetes_service_account" "master_sa" {
  metadata {
    name      = "network-metrics-master-sa"
    namespace = "default" # Adjust if using a different namespace
  }
}

# ClusterRole for the master
resource "kubernetes_cluster_role" "master_role" {
  metadata {
    name = "network-metrics-master-role"
  }

  rule {
    api_groups = [""]
    resources  = ["nodes", "pods"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["network.example.com"]
    resources  = ["networkmetrics"]
    verbs      = ["get", "list", "watch", "create", "update", "patch"]
  }
}

# ClusterRoleBinding for the master
resource "kubernetes_cluster_role_binding" "master_role_binding" {
  metadata {
    name = "network-metrics-master-role-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.master_role.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.master_sa.metadata[0].name
    namespace = kubernetes_service_account.master_sa.metadata[0].namespace
  }
}

# Deployment for the master
resource "kubernetes_deployment" "master" {
  metadata {
    name = "network-metrics-master"
    labels = {
      app = "network-metrics-master"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "network-metrics-master"
      }
    }

    template {
      metadata {
        labels = {
          app = "network-metrics-master"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.master_sa.metadata[0].name

        container {
          image = "jinnkenny99/network-metric-collector-master"
          name  = "network-metrics-master"

          port {
            container_port = 8080
          }

          env {
            name = "POD_IP"
            value_from {
              field_ref {
                field_path = "status.podIP"
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_manifest.network_metrics_crd]
}

# Service to expose the master
resource "kubernetes_service" "master_service" {
  depends_on = [kubernetes_deployment.master]
  metadata {
    name = "network-metrics-master-service"
  }

  spec {
    selector = {
      app = kubernetes_deployment.master.metadata[0].labels.app
    }

    port {
      port        = 8080
      target_port = 8080
    }

    type = "ClusterIP"
  }
}

# Service Account for the DaemonSet
resource "kubernetes_service_account" "daemonset_sa" {
  metadata {
    name      = "network-metrics-collector-sa"
    namespace = "default" # Adjust if using a different namespace
  }
}

# ClusterRole for the DaemonSet
resource "kubernetes_cluster_role" "daemonset_role" {
  metadata {
    name = "network-metrics-collector-role"
  }

  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["get", "list", "watch"]
  }
}

# ClusterRoleBinding for the DaemonSet
resource "kubernetes_cluster_role_binding" "daemonset_role_binding" {
  metadata {
    name = "network-metrics-collector-role-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.daemonset_role.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.daemonset_sa.metadata[0].name
    namespace = kubernetes_service_account.daemonset_sa.metadata[0].namespace
  }
}

# DaemonSet for network metric collection
resource "kubernetes_daemonset" "network_metrics" {
  metadata {
    name = "network-metrics-collector"
    labels = {
      app = "network-metrics-collector"
    }
  }

  spec {
    selector {
      match_labels = {
        app = "network-metrics-collector"
      }
    }

    template {
      metadata {
        labels = {
          app = "network-metrics-collector"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.daemonset_sa.metadata[0].name

        container {
          image = "jinnkenny99/network-metric-collector-daemonset"
          name  = "network-metrics-collector"

          port {
            container_port = 8080
          }

          env {
            name  = "MASTER_SERVER_URL"
            value = "http://${kubernetes_service.master_service.metadata[0].name}:8080"
          }

          env {
            name = "NODE_NAME"
            value_from {
              field_ref {
                field_path = "spec.nodeName"
              }
            }
          }

          env {
            name = "POD_IP"
            value_from {
              field_ref {
                field_path = "status.podIP"
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_manifest.network_metrics_crd]
}
