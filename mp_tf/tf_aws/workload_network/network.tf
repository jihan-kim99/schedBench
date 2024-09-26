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
              "topologyKey" = "topology.kubernetes.io/region"
              "originList" = [
                {
                  "origin" = "r1"
                  "costList" = [
                    {
                      "destination"        = "r2"
                      "networkCost"        = 0
                      "bandwidthAllocated" = "1Gi"
                      "bandwidthCapacity"  = "10Gi"
                    }
                  ]
                },
                {
                  "origin" = "r2"
                  "costList" = [
                    {
                      "destination"        = "r1"
                      "networkCost"        = 0
                      "bandwidthAllocated" = "1Gi"
                      "bandwidthCapacity"  = "10Gi"
                    }
                  ]
                }
              ]
            },
            {
              "topologyKey" = "topology.kubernetes.io/zone"
              "originList" = [
                {
                  "origin" = "z1"
                  "costList" = [
                    {
                      "destination"       = "z2"
                      "networkCost"       = 0
                      "bandwidthCapacity" = "1Gi"
                    }
                  ]
                },
                {
                  "origin" = "z2"
                  "costList" = [
                    {
                      "destination"       = "z1"
                      "networkCost"       = 0
                      "bandwidthCapacity" = "1Gi"
                    }
                  ]
                },
                {
                  "origin" = "z3"
                  "costList" = [
                    {
                      "destination"       = "z4"
                      "networkCost"       = 0
                      "bandwidthCapacity" = "1Gi"
                    }
                  ]
                },
                {
                  "origin" = "z4"
                  "costList" = [
                    {
                      "destination"       = "z3"
                      "networkCost"       = 0
                      "bandwidthCapacity" = "1Gi"
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
