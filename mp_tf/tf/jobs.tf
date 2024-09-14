resource "kubernetes_job" "master" {
  wait_for_completion = true

  timeouts {
    create = "2m"
    update = "2m"
  }

  metadata {
    name = "mp-test-0"
  }

  spec {
    parallelism = 1
    completions = 1
    template {
      metadata {
        labels = {
          app = "mp-test-0"
        }
      }
      spec {
        init_container {
          name  = "mp-test-0"
          image = "jinnkenny99/mp-test-init:latest"
          env {
            name  = "RANK"
            value = "0"
          }
          volume_mount {
            name       = "mp-pvc"
            mount_path = "/mnt/data"
          }
        }
        container {
          name  = "mp-test-0"
          image = "jinnkenny99/mp-test:latest"
          env {
            name  = "RANK"
            value = "0"
          }
          env {
            name  = "WORLD_SIZE"
            value = "3"
          }
          volume_mount {
            name       = "mp-pvc"
            mount_path = "/mnt/data"
          }
        }
        volume {
          name = "mp-pvc"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.mp_pvc.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_job" "worker1" {
  metadata {
    name = "mp-test-1"
  }
  wait_for_completion = true

  timeouts {
    create = "2m"
    update = "2m"
  }

  spec {
    parallelism = 1
    completions = 1
    template {
      metadata {
        labels = {
          app = "mp-test-1"
        }
      }
      spec {
        init_container {
          name  = "mp-test-1-init"
          image = "jinnkenny99/mp-test-init:latest"
          env {
            name  = "RANK"
            value = "1"
          }
          volume_mount {
            name       = "mp-pvc"
            mount_path = "/mnt/data"
          }
        }
        container {
          name  = "mp-test-1"
          image = "jinnkenny99/mp-test:latest"
          env {
            name  = "RANK"
            value = "1"
          }
          env {
            name  = "WORLD_SIZE"
            value = "3"
          }
          volume_mount {
            name       = "mp-pvc"
            mount_path = "/mnt/data"
          }
        }
        volume {
          name = "mp-pvc"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.mp_pvc.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_job" "worker2" {
  metadata {
    name = "mp-test-2"
  }

  wait_for_completion = true

  timeouts {
    create = "2m"
    update = "2m"
  }

  spec {
    parallelism = 1
    completions = 1
    template {
      metadata {
        labels = {
          app = "mp-test-2"
        }
      }
      spec {
        init_container {
          name  = "mp-test-2-init"
          image = "jinnkenny99/mp-test-init:latest"
          env {
            name  = "RANK"
            value = "2"
          }
          volume_mount {
            name       = "mp-pvc"
            mount_path = "/mnt/data"
          }
        }
        container {
          name  = "mp-test-2"
          image = "jinnkenny99/mp-test:latest"
          env {
            name  = "RANK"
            value = "2"
          }
          env {
            name  = "WORLD_SIZE"
            value = "3"
          }
          volume_mount {
            name       = "mp-mp-pvc"
            mount_path = "/mnt/data"
          }
        }
        volume {
          name = "mp-pvc"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.mp_pvc.metadata[0].name
          }
        }
      }
    }
  }
}
