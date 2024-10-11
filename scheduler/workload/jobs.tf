variable "ranks" {
  type    = list(number)
  default = [0, 1, 2]
}

variable "nodes" {
  type    = list(number)
  default = [1, 3, 5]
}

resource "kubernetes_job" "master" {
  count = length(var.ranks)
  metadata {
    name = "mp-test-${count.index}"
  }

  spec {
    parallelism = 1
    completions = 1
    template {
      metadata {
        labels = {
          app = "mp-test-${count.index}"
        }
      }
      spec {
        # affinity {
        #   node_affinity {
        #     required_during_scheduling_ignored_during_execution {
        #       node_selector_term {
        #         match_expressions {
        #           key      = "kubernetes.io/hostname"
        #           operator = "In"
        #           values   = ["worker-${var.nodes[count.index]}"]
        #         }
        #       }
        #     }
        #   }
        # }
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
