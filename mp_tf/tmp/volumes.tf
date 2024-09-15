resource "kubernetes_persistent_volume" "mp_pv" {
  metadata {
    name = "mp-pv"
  }

  spec {
    storage_class_name = "standard"
    persistent_volume_source {
      nfs {
        server = kubernetes_service.nfs_service.metadata[0].name
        path   = "/nfsshare"
      }
    }
    capacity = {
      storage = "1Gi"
    }
    access_modes = ["ReadWriteMany"]
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
