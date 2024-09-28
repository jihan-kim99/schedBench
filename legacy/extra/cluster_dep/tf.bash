terraform apply --auto-approve

aws eks --region $(terraform output -raw region) update-kubeconfig \
    --name $(terraform output -raw cluster_name)

git clone https://github.com/diktyo-io/helm-chart.git
helm install scheduler-plugins ./helm-chart/charts/as-a-second-scheduler --create-namespace --namespace scheduler-plugins