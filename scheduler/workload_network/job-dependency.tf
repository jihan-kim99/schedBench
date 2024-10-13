resource "kubernetes_manifest" "distributed_job" {
  manifest = {
    apiVersion = "batch.ddl.com/v1"
    kind       = "DistributedJob"
    metadata = {
      name      = "distributedjob1"
      namespace = "default"
    }
    spec = {
      workloads = [
        {
          resource = "top-layer"
          dependencies = [
            {
              resource = "mid-layer"
              bandwidth = {
                requests = 250
                limits   = 50
              }
              latency = {
                requests = 10
                limits   = 120
              }
            }
          ]
        },
        {
          resource = "mid-layer"
          dependencies = [
            {
              resource = "bottom-layer"
              bandwidth = {
                requests = 500
                limits   = 50
              }
              latency = {
                requests = 10
                limits   = 120
              }
            }
          ]
        },
        {
          resource = "bottom-layer"
        }
      ]
    }
  }
}
