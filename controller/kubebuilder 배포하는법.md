kubebuilder 폴더 들가기  
kubebuilder init --domain ddl.com --repo custom-scheduler  
kubebuilder create api --group batch --version v1 --kind DistributedJob  

## 결론
make generate && make manifests && make install
k apply -f clusterRole.yaml
make docker-build docker-push IMG=jinnkenny99/ddl:v1.0.13
make deploy IMG=jinnkenny99/ddl:v1.0.13

---

### CRD 배포
api/v1/distributedJob_types.go 수정  
make generate && make manifests && make install

### controller 배포
controllers/distributedJob_controller.go 수정  
kx distributedjob distributedjob1 && kx deploy deploy1
<<<<<<< Updated upstream

=======
make docker-build docker-push IMG=rfvtgbyh11/ddl:v1.0.14
make deploy IMG=rfvtgbyh11/ddl:v1.0.14
>>>>>>> Stashed changes

---

### Prerequisites
controller가 pod 정보를 쓰기 때문에

```
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
```
  

```
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kubebuilder-controller-manager-pod-reader
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: pod-reader
subjects:
- kind: ServiceAccount
  name: kubebuilder-controller-manager
  namespace: kubebuilder-system
```  
  
이거 2개 apply해야댐

> config/rbac/role.yaml 파일에 등록해놓음 괜찮을듯?