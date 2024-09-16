variable "ranks" {
  type    = list(number)
  default = [0, 1, 2]
}

resource "kubernetes_manifest" "pg1" {
  manifest = {
    apiVersion = "scheduling.x-k8s.io/v1alpha1"
    kind       = "PodGroup"
    metadata = {
      name      = "pg1"
      namespace = "default"
    }
    spec = {
      scheduleTimeoutSeconds = 10
      minMember              = 4
    }
  }
}


resource "kubernetes_job" "master" {
  depends_on = [kubernetes_service.ip_service, kubernetes_deployment.ip_server, kubernetes_manifest.pg1]
  count      = length(var.ranks)
  metadata {
    name = "mp-test-${count.index}"
    labels = {
      "pod-group.scheduling.sigs.k8s.io/name" = "pg1"
    }
  }

  # wait_for_completion = true
  # timeouts {
  #   create = "10m"
  #   update = "2m"
  # }
  spec {
    parallelism = 1
    completions = 1
    template {
      metadata {
        labels = {
          app                                     = "mp-test-${count.index}"
          "pod-group.scheduling.sigs.k8s.io/name" = "pg1"
        }
      }
      spec {
        container {
          name  = "mp-test-${count.index}"
          image = "jinnkenny99/mp-test:latest"
          env {
            name  = "RANK"
            value = var.ranks[count.index]
          }
          env {
            name  = "WORLD_SIZE"
            value = length(var.ranks)
          }
        }
      }
    }
  }
}
