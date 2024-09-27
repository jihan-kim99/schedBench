kubectl port-forward svc/my-prometheus-grafana 3001:80
kubectl port-forward svc/my-prometheus-kube-prometh-prometheus 9090:9090

kubectl port-forward --namespace monitoring service/grafana 3000:80
kubectl port-forward svc/prometheus-grafana 3001:80
kubectl port-forward svc/prometheus-kube-prometh-prometheus 9090:9090

k port-forward -n monitoring svc/prometheus-server 9090:80

- query
sum by(instance, mode) (rate(node_cpu_seconds_total[5m])) / on(instance) group_left sum by(instance) (rate(node_cpu_seconds_total[5m])) * 100

avg(rate(node_network_receive_bytes_total[1m])) by (instance) + avg(rate(node_network_transmit_bytes_total[1m])) by (instance)


- network latency and bandwidth

sudo apt install dnf
curl -O https://rpmfind.net/linux/fedora/linux/development/rawhide/Everything/aarch64/os/Packages/i/iproute-tc-6.10.0-1.fc41.aarch64.rpm
sudo dnf install ./iproute-tc-6.10.0-1.fc41.aarch64.rpm

- latency
sudo tc qdisc add dev ens5 root netem delay 100ms

- bandwidth
sudo tc qdisc add dev ens5 root tbf rate 1mbit burst 32kbit latency 400ms

- destroy
sudo tc qdisc del dev ens5 root