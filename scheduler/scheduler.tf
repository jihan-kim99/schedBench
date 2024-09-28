data "external" "directory_checksum" {
  program = ["bash", "-c", <<EOT
    checksum=$(find ${path.module}/sched_docker -type f -exec sha256sum {} + | sha256sum | awk '{print $1}')

    # Check if checksum file exists
    if [ -f ${path.module}/checksum ]; then
      # Read the stored checksum
      previous_checksum=$(cat ${path.module}/checksum)
    else
      previous_checksum=""
    fi

    # Save the new checksum to a file for future runs
    echo "$checksum" > ${path.module}/checksum

    # Output the current and previous checksums
    echo "{\"current_checksum\": \"$checksum\", \"previous_checksum\": \"$previous_checksum\"}"
  EOT
  ]
}

resource "null_resource" "check_and_build_scheduler" {
  triggers = {
    scheduler_checksum = data.external.directory_checksum.result["current_checksum"]
  }

  provisioner "local-exec" {
    command = <<EOT
      current_checksum=${data.external.directory_checksum.result["current_checksum"]}
      previous_checksum=${data.external.directory_checksum.result["previous_checksum"]}

      # Check if the checksum has changed
      if [ "$current_checksum" != "$previous_checksum" ]; then
        echo "Code has changed, building the custom scheduler..."
        docker build -t test-scheduler sched_docker
        docker tag test-scheduler jinnkenny99/test-scheduler
        docker push jinnkenny99/test-scheduler
      else
        echo "No changes detected. Skipping build."
      fi
    EOT
  }
}

resource "kubernetes_deployment" "scheduler" {
  #   depends_on = [null_resource.check_and_build_scheduler]
  metadata {
    name      = "scheduler"
    namespace = "scheduler"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "scheduler"
      }
    }
    template {
      metadata {
        labels = {
          app = "scheduler"
        }
      }
      spec {
        service_account_name = kubernetes_service_account.scheduler.metadata.0.name
        container {
          name  = "scheduler"
          image = "jinnkenny99/test-scheduler"
        }
      }
    }
  }
}
