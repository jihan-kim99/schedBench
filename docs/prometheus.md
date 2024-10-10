#prom-graf install
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
kubectl create namespace monitoring
helm install prometheus prometheus-community/prometheus --namespace monitoring
helm install grafana grafana/grafana --namespace monitoring
kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

kubectl port-forward --namespace monitoring service/grafana 3000:80
kubectl port-forward svc/prometheus-grafana 3001:80
kubectl port-forward svc/prometheus-kube-prometh-prometheus 9090:9090

k port-forward -n monitoring svc/prometheus-server 9090:80

- query
sum by(instance, mode) (rate(node_cpu_seconds_total[5m])) / on(instance) group_left sum by(instance) (rate(node_cpu_seconds_total[5m])) * 100

avg(rate(node_network_receive_bytes_total[1m])) by (instance) + avg(rate(node_network_transmit_bytes_total[1m])) by (instance)