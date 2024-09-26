variable "ranks" {
  type    = list(number)
  default = [0, 1, 2]
}

resource "kubernetes_job" "master" {
  depends_on = [kubernetes_service.ip_service, kubernetes_deployment.ip_server]
  count      = length(var.ranks)
  metadata {
    name = "mp-test-${count.index}"
  }

  spec {
    parallelism = 1
    completions = 1
    template {
      metadata {
        labels = {
          app                                 = "mp-test-${count.index}"
          "appgroup.diktyo.x-k8s.io.workload" = "mp-test-${count.index}"
        }
      }
      spec {
        scheduler_name = "diktyo-scheduler"
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
          resources {
            limits = {
              cpu = "2"
            }
            requests = {
              cpu = "1"
            }
          }
        }
      }
    }
  }
}
