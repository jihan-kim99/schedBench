terraform apply --auto-approve


echo "Setting KUBECONFIG environment variable..."
KUBECONFIG=/home/jihan/schedBench/mp_tf/tf_aws/adm_cluster/jolp.conf:~/.kube/config kubectl config view --flatten > ~/.kube/config

# install calico
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# echo "Installing the scheduler-plugins helm chart..."
# # Check if the helm-chart directory exists
# if [ ! -d "helm-chart" ]; then
#   echo "Cloning the helm-chart repository..."
#   git clone https://github.com/diktyo-io/helm-chart.git
# else
#   echo "helm-chart directory already exists. Skipping clone."
# fi
# helm install scheduler-plugins ./helm-chart/charts/as-a-second-scheduler --create-namespace --namespace scheduler-plugins


cat <<'EOF'
 (\(\ 
 ( -.-)
 o_(")(")
EOF

echo "All done!"