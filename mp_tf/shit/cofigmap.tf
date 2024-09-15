resource "kubernetes_config_map" "mp_configmap" {
  metadata {
    name = "mp-configmap"
  }

  data = {}
}
