variable "ranks" {
  type    = list(number)
  default = [0, 1, 2]
}

variable "layers" {
  type    = list(string)
  default = ["bottom-layer", "mid-layer", "top-layer"]
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

resource "kubernetes_job" "master1" {
  count = length(var.ranks)
  metadata {
    name = "mp-test1-${count.index}"
  }

  spec {
    parallelism = 1
    completions = 1
    template {
      metadata {
        labels = {
          app      = "mp-test1-${count.index}"
          resource = "${var.layers[count.index]}"
        }
      }
      spec {
        scheduler_name = "scheduler-plugins-scheduler"
        container {
          name  = "mp-test1-${count.index}"
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
            value = kubernetes_service.master_service1.metadata[0].name
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

resource "kubernetes_service" "master_service1" {
  metadata {
    name = "master-service"
  }
  spec {
    selector = {
      app = "mp-test1-0"
    }
    port {
      port        = 80
      target_port = 80
    }
  }
}
resource "kubernetes_job" "master2" {
  count = length(var.ranks)
  metadata {
    name = "mp-test2-${count.index}"
  }

  spec {
    parallelism = 1
    completions = 1
    template {
      metadata {
        labels = {
          app      = "mp-test2-${count.index}"
          resource = "${var.layers[count.index]}"
        }
      }
      spec {
        scheduler_name = "scheduler-plugins-scheduler"
        container {
          name  = "mp-test2-${count.index}"
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
            value = kubernetes_service.master_service2.metadata[0].name
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

resource "kubernetes_service" "master_service2" {
  metadata {
    name = "master-service"
  }
  spec {
    selector = {
      app = "mp-test2-0"
    }
    port {
      port        = 80
      target_port = 80
    }
  }
}
