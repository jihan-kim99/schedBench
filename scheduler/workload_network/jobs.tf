variable "ranks" {
  type    = list(number)
  default = [0, 1, 2]
}

variable "layers" {
  type    = list(string)
  default = ["top-layer", "mid-layer", "bottom-layer"]
}

resource "kubernetes_job" "master" {
  depends_on = [kubernetes_manifest.distributed_job]
  count      = length(var.ranks)

  wait_for_completion = true
  timeouts {
    create = "2m"
    update = "2m"
  }
  metadata {
    name = "mp-test-${count.index}"
  }

  spec {
    parallelism = 1
    completions = 1
    template {
      metadata {
        labels = {
          app      = "mp-test-${count.index}"
          resource = "${var.layers[count.index]}"
        }
      }
      spec {
        scheduler_name = "scheduler-plugins-scheduler"
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
          env {
            name  = "MASTER_ADDR"
            value = kubernetes_service.master_service.metadata[0].name
          }
          env {
            name  = "MASTER_PORT"
            value = "80"
          }
          resources {
            limits = {
              cpu = "1500m"
            }
            requests = {
              cpu = "1000m"
            }
          }
        }
        restart_policy = "Never"
      }
    }
  }
}

resource "kubernetes_service" "master_service" {
  metadata {
    name = "master-service"
  }
  spec {
    selector = {
      app = "mp-test-0"
    }
    port {
      port        = 80
      target_port = 80
    }
  }
}
