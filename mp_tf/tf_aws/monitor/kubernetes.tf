terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.11.0"
    }
  }
}

provider "helm" {
  kubernetes {
    config_path = "../adm_cluster/jolp.conf"
  }
}

provider "kubernetes" {
  config_path = "../adm_cluster/jolp.conf"
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

# Update the Grafana Helm release to use the new PVC
resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  values = [
    <<-EOT
    persistence:
      enabled: false
    EOT
  ]

  depends_on = [kubernetes_namespace.monitoring]
}

resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  values = [
    <<-EOT
    server:
      global:
        scrape_interval: 15s
        evaluation_interval: 15s
        external_labels:
          cluster: my-cluster
      persistentVolume:
        enabled: false
      emptyDir:
        medium: Memory
        sizeLimit: 8Gi
      extraArgs:
        web.external-url: http://prometheus.example.com
        log.level: debug
      readinessProbeInitialDelay: 30
      readinessProbePeriodSeconds: 5
      resources:
        requests:
          cpu: 250m
          memory: 1Gi
        limits:
          cpu: 500m
          memory: 2Gi
    
    alertmanager:
      enabled: false
    EOT
  ]

  set {
    name  = "server.enableAdminApi"
    value = "true"
  }

  depends_on = [kubernetes_namespace.monitoring]
}

resource "null_resource" "port_forward" {
  provisioner "local-exec" {
    command = <<-EOF
      kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
      kubectl port-forward --namespace monitoring service/grafana 3000:80
    EOF
  }
}
