resource "kubernetes_manifest" "appgroup_a1" {
  manifest = {
    "apiVersion" = "appgroup.diktyo.x-k8s.io/v1alpha1"
    "kind"       = "AppGroup"
    "metadata" = {
      "name"      = "a1"
      "namespace" = "default"
    }
    "spec" = {
      "numMembers"               = 3
      "topologySortingAlgorithm" = "KahnSort"
      "workloads" = [
        {
          "workload" = {
            "kind"       = "Deployment"
            "name"       = "mp-test-0"
            "selector"   = "mp-test-0"
            "apiVersion" = "apps/v1"
            "namespace"  = "default"
          }
          "dependencies" = [
            {
              "workload" = {
                "kind"       = "Deployment"
                "name"       = "mp-test-1"
                "selector"   = "mp-test-1"
                "apiVersion" = "apps/v1"
                "namespace"  = "default"
              }
              "minBandwidth"   = "30Mi"
              "maxNetworkCost" = 0
            }
          ]
        },
        {
          "workload" = {
            "kind"       = "Deployment"
            "name"       = "mp-test-1"
            "selector"   = "mp-test-1"
            "apiVersion" = "apps/v1"
            "namespace"  = "default"
          }
          "dependencies" = [
            {
              "workload" = {
                "kind"       = "Deployment"
                "name"       = "mp-test-2"
                "selector"   = "mp-test-2"
                "apiVersion" = "apps/v1"
                "namespace"  = "default"
              }
              "minBandwidth"   = "30Mi"
              "maxNetworkCost" = 0
            }
          ]
        },
        {
          "workload" = {
            "kind"       = "Deployment"
            "name"       = "mp-test-2"
            "selector"   = "mp-test-2"
            "apiVersion" = "apps/v1"
            "namespace"  = "default"
          }
          "dependencies" = [
            {
              "workload" = {
                "kind"       = "Deployment"
                "name"       = "mp-test-0"
                "selector"   = "mp-test-0"
                "apiVersion" = "apps/v1"
                "namespace"  = "default"
              }
              "minBandwidth"   = "30Mi"
              "maxNetworkCost" = 0
            }
          ]
        }
      ]
    }
  }
}
