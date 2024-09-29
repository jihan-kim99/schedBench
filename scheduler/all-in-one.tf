resource "kubernetes_service_account" "network_aware_scheduler" {
  metadata {
    name      = "network-aware-scheduler"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role" "network_aware_scheduler_handler" {
  metadata {
    name = "network-aware-scheduler-handler"
  }

  rule {
    api_groups = ["scheduling.sigs.x-k8s.io"]
    resources  = ["podgroups", "elasticquotas", "podgroups/status", "elasticquotas/status"]
    verbs      = ["get", "list", "watch", "create", "delete", "update", "patch"]
  }

  rule {
    api_groups = ["appgroup.diktyo.x-k8s.io"]
    resources  = ["appgroups"]
    verbs      = ["get", "list", "watch", "create", "delete", "update", "patch"]
  }

  rule {
    api_groups = ["networktopology.diktyo.x-k8s.io"]
    resources  = ["networktopologies"]
    verbs      = ["get", "list", "watch", "create", "delete", "update", "patch"]
  }
}

resource "kubernetes_cluster_role_binding" "network_aware_scheduler_as_kube_scheduler" {
  metadata {
    name = "network-aware-scheduler-as-kube-scheduler"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.network_aware_scheduler_handler.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.network_aware_scheduler.metadata[0].name
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding" "my_scheduler_as_volume_scheduler" {
  metadata {
    name = "my-scheduler-as-volume-scheduler"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "system:volume-scheduler"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "my-scheduler"
    namespace = "kube-system"
  }
}

resource "kubernetes_role_binding" "network_aware_scheduler_as_kube_scheduler" {
  metadata {
    name      = "network-aware-scheduler-as-kube-scheduler"
    namespace = "kube-system"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "extension-apiserver-authentication-reader"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.network_aware_scheduler.metadata[0].name
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding" "networkawarescheduler" {
  metadata {
    name = "networkawarescheduler"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.network_aware_scheduler_handler.metadata[0].name
  }

  subject {
    kind      = "User"
    name      = "system:kube-scheduler"
    namespace = "kube-system"
    api_group = "rbac.authorization.k8s.io"
  }
}


resource "kubernetes_manifest" "networktopology_crd" {
  manifest = {
    apiVersion = "apiextensions.k8s.io/v1"
    kind       = "CustomResourceDefinition"
    metadata = {
      annotations = {
        "controller-gen.kubebuilder.io/version" = "v0.14.0"
      }
      name = "networktopologies.networktopology.diktyo.x-k8s.io"
    }
    spec = {
      group = "networktopology.diktyo.x-k8s.io"
      names = {
        kind       = "NetworkTopology"
        listKind   = "NetworkTopologyList"
        plural     = "networktopologies"
        singular   = "networktopology"
        shortNames = ["nt"]
      }
      scope = "Namespaced"
      versions = [
        {
          name    = "v1alpha1"
          served  = true
          storage = true
          schema = {
            openAPIV3Schema = {
              description = "NetworkTopology defines network costs in the cluster between regions and zones"
              type        = "object"
              properties = {
                apiVersion = {
                  description = "APIVersion defines the versioned schema of this representation of an object. Servers should convert recognized schemas to the latest internal value, and may reject unrecognized values. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources"
                  type        = "string"
                }
                kind = {
                  description = "Kind is a string value representing the REST resource this object represents. Servers may infer this from the endpoint the client submits requests to. Cannot be updated. In CamelCase. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds"
                  type        = "string"
                }
                metadata = {
                  type = "object"
                }
                spec = {
                  description = "NetworkTopologySpec defines the zones and regions of the cluster."
                  type        = "object"
                  required    = ["configmapName", "weights"]
                  properties = {
                    configmapName = {
                      description = "ConfigmapName to be used for cost calculation"
                      type        = "string"
                    }
                    weights = {
                      description = "The manual defined weights of the cluster"
                      type        = "array"
                      items = {
                        description = "WeightInfo contains information about all network costs for a given algorithm."
                        type        = "object"
                        required    = ["name", "topologyList"]
                        properties = {
                          name = {
                            description = "Algorithm Name for network cost calculation (e.g., userDefined)"
                            type        = "string"
                          }
                          topologyList = {
                            description = "TopologyList owns Costs between origins"
                            type        = "array"
                            items = {
                              description = "TopologyInfo contains information about network costs for a particular Topology Key."
                              type        = "object"
                              required    = ["originList", "topologyKey"]
                              properties = {
                                topologyKey = {
                                  description = "Topology key (e.g., \"topology.kubernetes.io/region\", \"topology.kubernetes.io/zone\")."
                                  type        = "string"
                                }
                                originList = {
                                  description = "OriginList for a particular origin."
                                  type        = "array"
                                  items = {
                                    description = "OriginInfo contains information about network costs for a particular Origin."
                                    type        = "object"
                                    required    = ["origin"]
                                    properties = {
                                      origin = {
                                        description = "Name of the origin (e.g., Region Name, Zone Name)."
                                        type        = "string"
                                      }
                                      costList = {
                                        description = "Costs for the particular origin."
                                        type        = "array"
                                        items = {
                                          description = "CostInfo contains information about networkCosts."
                                          type        = "object"
                                          required    = ["destination", "networkCost"]
                                          properties = {
                                            destination = {
                                              description = "Name of the destination (e.g., Region Name, Zone Name)."
                                              type        = "string"
                                            }
                                            networkCost = {
                                              description = "Network Cost between origin and destination (e.g., Dijkstra shortest path, etc)"
                                              type        = "integer"
                                              format      = "int64"
                                              minimum     = 0
                                            }
                                            bandwidthAllocated = {
                                              description                  = "Bandwidth allocated between origin and destination."
                                              anyOf                        = [{ type = "integer" }, { type = "string" }]
                                              pattern                      = "^(\\+|-)?(([0-9]+(\\.[0-9]*)?)|(\\.[0-9]+))(([KMGTPE]i)|[numkMGTPE]|([eE](\\+|-)?(([0-9]+(\\.[0-9]*)?)|(\\.[0-9]+))))?$"
                                              "x-kubernetes-int-or-string" = true
                                            }
                                            bandwidthCapacity = {
                                              description                  = "Bandwidth capacity between origin and destination."
                                              anyOf                        = [{ type = "integer" }, { type = "string" }]
                                              pattern                      = "^(\\+|-)?(([0-9]+(\\.[0-9]*)?)|(\\.[0-9]+))(([KMGTPE]i)|[numkMGTPE]|([eE](\\+|-)?(([0-9]+(\\.[0-9]*)?)|(\\.[0-9]+))))?$"
                                              "x-kubernetes-int-or-string" = true
                                            }
                                          }
                                        }
                                      }
                                    }
                                  }
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
                status = {
                  description = "NetworkTopologyStatus defines the observed use."
                  type        = "object"
                  properties = {
                    nodeCount = {
                      description = "The total number of nodes in the cluster"
                      type        = "integer"
                      format      = "int64"
                      minimum     = 0
                    }
                    weightCalculationTime = {
                      description = "The calculation time for the weights in the network topology CRD"
                      type        = "string"
                      format      = "date-time"
                    }
                  }
                }
              }
            }
          }
        }
      ]
    }
  }
}

resource "kubernetes_config_map" "network_aware_scheduler_config" {
  metadata {
    name      = "network-aware-scheduler-config"
    namespace = "kube-system"
  }

  data = {
    "scheduler-config.yaml" = yamlencode({
      apiVersion = "kubescheduler.config.k8s.io/v1"
      kind       = "KubeSchedulerConfiguration"
      leaderElection = {
        leaderElect = false
      }
      clientConnection = {
        kubeconfig = "/etc/kubernetes/scheduler.conf"
      }
      profiles = [
        {
          schedulerName = "network-aware-scheduler"
          plugins = {
            multiPoint = {
              enabled = [
                {
                  name   = "NetworkOverhead"
                  weight = 5
                }
              ]
              disabled = [
                {
                  name = "NodeResourcesFit"
                }
              ]
            }
            queueSort = {
              enabled = [
                {
                  name = "TopologicalSort"
                }
              ]
              disabled = [
                {
                  name = "*"
                }
              ]
            }
          }
          pluginConfig = [
            {
              name = "TopologicalSort"
              args = {
                namespaces = ["default"]
              }
            },
            {
              name = "NetworkOverhead"
              args = {
                namespaces          = ["default"]
                weightsName         = "UserDefined"
                networkTopologyName = "net-topology-test"
              }
            }
          ]
        }
      ]
    })
  }
}

# Assuming you're using a Deployment for the scheduler
resource "kubernetes_deployment" "network_aware_scheduler" {
  metadata {
    name      = "network-aware-scheduler"
    namespace = "kube-system"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "network-aware-scheduler"
      }
    }

    template {
      metadata {
        labels = {
          app = "network-aware-scheduler"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.network_aware_scheduler.metadata[0].name
        container {
          name  = "network-aware-scheduler"
          image = "jinnkenny99/scheduler" # Update this to the correct image for your network-aware scheduler
          command = [
            "kube-scheduler",
            "--config=/etc/kubernetes/scheduler-config/scheduler-config.yaml"
          ]
          volume_mount {
            name       = "scheduler-config"
            mount_path = "/etc/kubernetes/scheduler-config"
            read_only  = true
          }
        }
        volume {
          name = "scheduler-config"
          config_map {
            name = kubernetes_config_map.network_aware_scheduler_config.metadata[0].name
          }
        }
      }
    }
  }
}

# Create service account for networktopology controller
resource "kubernetes_service_account" "networktopology_controller" {
  metadata {
    name      = "networktopology-controller"
    namespace = "kube-system"
  }
}

# Create ClusterRole for networktopology controller
resource "kubernetes_cluster_role" "networktopology_controller" {
  metadata {
    name = "networktopology-controller"
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["get", "list", "watch", "patch"]
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["get", "list", "watch", "create", "delete", "update", "patch"]
  }

  rule {
    api_groups = ["appgroup.diktyo.x-k8s.io"]
    resources  = ["appgroups"]
    verbs      = ["get", "list", "watch", "create", "delete", "update", "patch"]
  }

  rule {
    api_groups = ["networktopology.diktyo.x-k8s.io"]
    resources  = ["networktopologies"]
    verbs      = ["get", "list", "watch", "create", "delete", "update", "patch"]
  }
}

# Create ClusterRoleBinding for networktopology controller
resource "kubernetes_cluster_role_binding" "networktopology_controller" {
  metadata {
    name = "networktopology-controller"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.networktopology_controller.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.networktopology_controller.metadata[0].name
    namespace = "kube-system"
  }
}

# Create Deployment for networktopology controller
resource "kubernetes_deployment" "networktopology_controller" {
  metadata {
    name      = "networktopology-controller"
    namespace = "kube-system"
    labels = {
      app = "networktopology-controller"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "networktopology-controller"
      }
    }

    template {
      metadata {
        labels = {
          app = "networktopology-controller"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.networktopology_controller.metadata[0].name

        container {
          name              = "networktopology-controller"
          image             = "jinnkenny99/controller"
          image_pull_policy = "IfNotPresent"
        }
      }
    }
  }
}
