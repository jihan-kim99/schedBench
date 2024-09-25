sudo docker exec -it $(sudo docker ps | grep control-plane | awk '{print $1}') bash
# Backup kube-scheduler.yaml && Create /etc/kubernetes/sched-cc.yaml

kubectl apply -f all-in-one.yaml
kubectl get deploy -n scheduler-plugins

kubectl apply -f crds/appgroup.diktyo.x-k8s.io_appgroups.yaml
kubectl apply -f crds/networktopology.diktyo.x-k8s.io_networktopologies.yaml
kubectl apply -f crds/scheduling.x-k8s.io_elasticquotas.yaml
kubectl apply -f crds/scheduling.x-k8s.io_podgroups.yaml
kubectl apply -f crds/seccompprofiles.security-profiles-operator.x-k8s.io_sysched.yaml
kubectl apply -f crds/security-profiles-operator.x-k8s.io_seccompprofiles.yaml
kubectl apply -f crds/topology.node.k8s.io_noderesourcetopologies.yaml

sudo docker exec -it $(sudo docker ps | grep control-plane | awk '{print $1}') bash
# Modify /etc/kubernetes/manifests/kube-scheduler.yaml

kubectl get pod -n kube-system | grep kube-scheduler
kubectl get pods -l component=kube-scheduler -n kube-system -o=jsonpath="{.items[0].spec.containers[0].image}{'\n'}"
# If get trouble, systemctl restart kubelet.service in control plane