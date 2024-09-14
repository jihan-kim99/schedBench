# Persistent Volume for NFS
resource "kubernetes_persistent_volume" "mp_pv" {
  metadata {
    name = "mp-pv"
  }

  spec {
    capacity = {
      storage = "1Gi"
    }
    access_modes = ["ReadWriteMany"]

    persistent_volume_source {
      nfs {
        # The NFS server address (use the Kubernetes service name or external IP if using an external server)
        server = kubernetes_service.nfs_service.metadata[0].name
        # The exported path from the NFS server (must match the directory being shared)
        path = "/nfsshare"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "mp_pvc" {
  metadata {
    name = "mp-pvc"
  }

  spec {
    access_modes = ["ReadWriteMany"]

    resources {
      requests = {
        storage = "1Gi"
      }
    }

    volume_name = kubernetes_persistent_volume.mp_pv.metadata[0].name
  }
}
