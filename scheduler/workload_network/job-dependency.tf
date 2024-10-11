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
                limits   = 20
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
                requests = 250
                limits   = 10
              }
              latency = {
                requests = 10
                limits   = 50
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
