resource "kubernetes_deployment" "nfs_server" {
  metadata {
    name = "nfs-server"
    labels = {
      app = "nfs-server"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "nfs-server"
      }
    }

    template {
      metadata {
        labels = {
          app = "nfs-server"
        }
      }

      spec {
        container {
          name  = "nfs-server"
          image = "itsthenetwork/nfs-server-alpine:latest"

          port {
            name           = "nfs"
            container_port = 2049
          }

          port {
            name           = "mountd"
            container_port = 20048
          }

          port {
            name           = "rpcbind"
            container_port = 111
          }

          security_context {
            capabilities {
              add = ["SYS_ADMIN", "SETPCAP"]
            }
          }

          env {
            name  = "SHARED_DIRECTORY"
            value = "/nfsshare"
          }

          volume_mount {
            name       = "nfs-data"
            mount_path = "/nfsshare"
          }
        }

        volume {
          name = "nfs-data"
          empty_dir {}
        }
      }
    }
  }
}

# NFS Service
resource "kubernetes_service" "nfs_service" {
  metadata {
    name = "nfs-service"
  }

  spec {
    selector = {
      app = "nfs-server"
    }

    cluster_ip = "None"

    port {
      name        = "nfs"
      port        = 2049
      target_port = 2049
    }

    port {
      name        = "mountd"
      port        = 20048
      target_port = 20048
    }

    port {
      name        = "rpcbind"
      port        = 111
      target_port = 111
    }
  }
}
