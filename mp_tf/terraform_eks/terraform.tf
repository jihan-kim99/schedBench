terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

variable "host" {
  type = string
}

variable "client_certificate" {
  type = string
}

variable "client_key" {
  type = string
}

variable "cluster_ca_certificate" {
  type = string
}

provider "kubernetes" {
  host = var.host

  client_certificate     = base64decode(var.client_certificate)
  client_key             = base64decode(var.client_key)
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
}

resource "kubernetes_storage_class" "storageClass" {
	metadata {
		name = "local-path"
	}
	storage_provisioner = "rancher.io/local-path"
	volume_binding_mode = "Immediate"
}

resource "kubernetes_persistent_volume" "mnist-pv" {
  metadata {
    name = "mnist-pv"
  }

	spec {
		persistent_volume_source {
			host_path {
				path = "/mnt/data"
			}
		}
		capacity = {
			storage = "10Gi"
		}
		access_modes = ["ReadWriteOnce"]
		storage_class_name = kubernetes_storage_class.storageClass.metadata[0].name
	}
}

resource "kubernetes_persistent_volume_claim" "mnist-pvc" {
	metadata {
		name = "mnist-pvc"
	}
	
	spec {
		access_modes = ["ReadWriteOnce"]
		resources {
			requests = {
				storage = "10Gi"
			}
		}
		storage_class_name = kubernetes_storage_class.storageClass.metadata[0].name
	}
}

resource "kubernetes_job" "mnist_0" {
	metadata {
		name = "mnist-0"
	}

	spec {
		template {
			metadata {
				labels = {
					app = "mnist"
				}
			}
			spec {
				init_container {
					name  = "write-rank0-ip"
					image = "jinnkenny99/ddl-init"

					volume_mount {
						name       = kubernetes_persistent_volume_claim.mnist-pvc.metadata[0].name
						mount_path = "/mnt/data"
					}

					env {
						name  = "RANK"
						value = "0"
					}
				}
				container {
					name  = "mnist"
					image = "jinnkenny99/dist-mnist:latest"

					env {
						name  = "WORLD_SIZE"
						value = "4"
					}

					env {
						name  = "RANK"
						value = "0"
					}

					env {
						name  = "MASTER_PORT"
						value = "80"
					}

					volume_mount {
						name       = kubernetes_persistent_volume_claim.mnist-pvc.metadata[0].name
						mount_path = "/mnt/data"
					}
				}

				volume {
					name = kubernetes_persistent_volume_claim.mnist-pvc.metadata[0].name

					persistent_volume_claim {
						claim_name = kubernetes_persistent_volume_claim.mnist-pvc.metadata[0].name
					}
				}

				restart_policy = "Never"
			}
		}
	}
}

resource "kubernetes_job" "mnist_1" {
	metadata {
		name = "mnist-1"
	}

	spec {
		template {
			metadata {
				labels = {
					app = "mnist"
				}
			}
			spec {
				init_container {
					name  = "write-rank0-ip"
					image = "jinnkenny99/ddl-init"

					volume_mount {
						name       = kubernetes_persistent_volume_claim.mnist-pvc.metadata[0].name
						mount_path = "/mnt/data"
					}

					env {
						name  = "RANK"
						value = "1"
					}
				}
				container {
					name  = "mnist"
					image = "jinnkenny99/dist-mnist:latest"

					env {
						name  = "WORLD_SIZE"
						value = "4"
					}

					env {
						name  = "RANK"
						value = "1"
					}

					env {
						name  = "MASTER_PORT"
						value = "80"
					}

					volume_mount {
						name       = kubernetes_persistent_volume_claim.mnist-pvc.metadata[0].name
						mount_path = "/mnt/data"
					}
				}

				volume {
					name = kubernetes_persistent_volume_claim.mnist-pvc.metadata[0].name

					persistent_volume_claim {
						claim_name = kubernetes_persistent_volume_claim.mnist-pvc.metadata[0].name
					}
				}

				restart_policy = "Never"
			}
		}
	}
}

resource "kubernetes_job" "mnist_2" {
	metadata {
		name = "mnist-2"
	}

	spec {
		template {
			metadata {
				labels = {
					app = "mnist"
				}
			}
			spec {
				init_container {
					name  = "read-rank0-ip"
					image = "jinnkenny99/ddl-init"

					volume_mount {
						name       = kubernetes_persistent_volume_claim.mnist-pvc.metadata[0].name
						mount_path = "/mnt/data"
					}

					env {
						name  = "RANK"
						value = "2"
					}
				}
				container {
					name  = "mnist"
					image = "jinnkenny99/dist-mnist:latest"

					env {
						name  = "WORLD_SIZE"
						value = "4"
					}

					env {
						name  = "RANK"
						value = "2"
					}

					env {
						name  = "MASTER_PORT"
						value = "80"
					}

					volume_mount {
						name       = kubernetes_persistent_volume_claim.mnist-pvc.metadata[0].name
						mount_path = "/mnt/data"
					}
				}

				volume {
					name = kubernetes_persistent_volume_claim.mnist-pvc.metadata[0].name

					persistent_volume_claim {
						claim_name = kubernetes_persistent_volume_claim.mnist-pvc.metadata[0].name
					}
				}

				restart_policy = "Never"
			}
		}
	}
}

resource "kubernetes_job" "mnist_3" {
	metadata {
		name = "mnist-3"
	}

	spec {
		template {
			metadata {
				labels = {
					app = "mnist"
				}
			}
			spec {
				init_container {
					name  = "read-rank0-ip"
					image = "jinnkenny99/ddl-init"

					volume_mount {
						name       = kubernetes_persistent_volume_claim.mnist-pvc.metadata[0].name
						mount_path = "/mnt/data"
					}

					env {
						name  = "RANK"
						value = "3"
					}
				}
				container {
					name  = "mnist"
					image = "jinnkenny99/dist-mnist:latest"

					env {
						name  = "WORLD_SIZE"
						value = "4"
					}

					env {
						name  = "RANK"
						value = "3"
					}

					env {
						name  = "MASTER_PORT"
						value = "80"
					}

					volume_mount {
						name       = kubernetes_persistent_volume_claim.mnist-pvc.metadata[0].name
						mount_path = "/mnt/data"
					}
				}

				volume {
					name = kubernetes_persistent_volume_claim.mnist-pvc.metadata[0].name

					persistent_volume_claim {
						claim_name = kubernetes_persistent_volume_claim.mnist-pvc.metadata[0].name
					}
				}

				restart_policy = "Never"
			}
		}
	}
}