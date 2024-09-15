resource "kubernetes_deployment" "nfs" {
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

          volume_mount {
            name       = "nfs-share"
            mount_path = "/nfsshare"
          }
          env {
            name  = "SHARED_DIRECTORY"
            value = "/nfsshare"
          }
        }

        volume {
          name = "nfs-share"
          empty_dir {}
        }
      }
    }
  }
}


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

