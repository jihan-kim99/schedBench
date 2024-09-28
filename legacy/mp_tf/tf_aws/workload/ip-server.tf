resource "kubernetes_deployment" "ip_server" {
  metadata {
    name = "ip-server"
    labels = {
      app = "ip-server"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "ip-server"
      }
    }
    template {
      metadata {
        labels = {
          app = "ip-server"
        }
      }
      spec {
        container {
          image = "jinnkenny99/ip-server"
          name  = "ip-server"

          port {
            name           = "http"
            container_port = 8000
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "ip_service" {
  metadata {
    name = "ip-service"
  }
  spec {
    selector = {
      app = "ip-server"
    }
    port {
      port        = 8000
      target_port = 8000
    }
  }

}
