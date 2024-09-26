kubectl port-forward svc/my-prometheus-grafana 3001:80
kubectl port-forward svc/my-prometheus-kube-prometh-prometheus 9090:9090

kubectl port-forward --namespace monitoring service/grafana 3000:80
kubectl port-forward svc/prometheus-grafana 3001:80
kubectl port-forward svc/prometheus-kube-prometh-prometheus 9090:9090

k port-forward -n monitoring svc/prometheus-server 9090:80