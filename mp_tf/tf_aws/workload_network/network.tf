resource "kubernetes_manifest" "network_topology_nt_cluster" {
  manifest = {
    "apiVersion" = "networktopology.diktyo.x-k8s.io/v1alpha1"
    "kind"       = "NetworkTopology"
    "metadata" = {
      "name"      = "nt-cluster"
      "namespace" = "default"
    }
    "spec" = {
      "configmapName" = "netperfMetrics"
      "weights" = [
        {
          "name" = "UserDefined"
          "topologyList" = [
            {
              "topologyKey" = "topology.kubernetes.io/zone"
              "originList" = [
                {
                  "origin" = "z1"
                  "costList" = [
                    {
                      "destination"       = "z2"
                      "networkCost"       = 0
                      "bandwidthCapacity" = "50Mi"
                    },
                    {
                      "destination"       = "z3"
                      "networkCost"       = 0
                      "bandwidthCapacity" = "20Mi"
                    },
                    {
                      "destination"       = "z4"
                      "networkCost"       = 0
                      "bandwidthCapacity" = "50Mi"
                    }
                  ]
                },
                {
                  "origin" = "z2"
                  "costList" = [
                    {
                      "destination"       = "z1"
                      "networkCost"       = 0
                      "bandwidthCapacity" = "50Mi"
                    },
                    {
                      "destination"       = "z3"
                      "networkCost"       = 0
                      "bandwidthCapacity" = "20Mi"
                    },
                    {
                      "destination"       = "z4"
                      "networkCost"       = 0
                      "bandwidthCapacity" = "50Mi"
                    }
                  ]
                },
                {
                  "origin" = "z3"
                  "costList" = [
                    {
                      "destination"       = "z1"
                      "networkCost"       = 0
                      "bandwidthCapacity" = "20Mi"
                    },
                    {
                      "destination"       = "z2"
                      "networkCost"       = 0
                      "bandwidthCapacity" = "20Mi"
                    },
                    {
                      "destination"       = "z4"
                      "networkCost"       = 0
                      "bandwidthCapacity" = "20Mi"
                    }
                  ]
                },
                {
                  "origin" = "z4"
                  "costList" = [
                    {
                      "destination"       = "z1"
                      "networkCost"       = 0
                      "bandwidthCapacity" = "50Mi"
                    },
                    {
                      "destination"       = "z2"
                      "networkCost"       = 0
                      "bandwidthCapacity" = "50Mi"
                    },
                    {
                      "destination"       = "z3"
                      "networkCost"       = 0
                      "bandwidthCapacity" = "20Mi"
                    }
                  ]
                }
              ]
            }
          ]
        }
      ]
    }
  }
}
