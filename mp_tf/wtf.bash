#!/bin/bash

# Get the values from kubectl
server=$(kubectl config view --minify --flatten --context=kind-kind -o jsonpath='{.clusters[].cluster.server}')
certificate_authority_data=$(kubectl config view --minify --flatten --context=kind-kind -o jsonpath='{.clusters[].cluster.certificate-authority-data}')
client_certificate_data=$(kubectl config view --minify --flatten --context=kind-kind -o jsonpath='{.users[].user.client-certificate-data}')
client_key_data=$(kubectl config view --minify --flatten --context=kind-kind -o jsonpath='{.users[].user.client-key-data}')

# Write to terraform.tfvars
cat <<EOF > tf/terraform.tfvars
host                   = "${server}"
client_certificate     = "${client_certificate_data}"
cluster_ca_certificate = "${certificate_authority_data}"
client_key             = "${client_key_data}"
EOF
