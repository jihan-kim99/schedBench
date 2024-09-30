kubebuilder 폴더 들가기  
kubebuilder init --domain ddl.com --repo custom-scheduler  
kubebuilder create api --group batch --version v1 --kind DistributedJob  

---

### CRD 배포
api/v1/distributedJob_types.go 수정  
make generate && make manifests && make install  

### controller 배포
controllers/distributedJob_controller.go 수정  
make docker-build docker-push IMG=rfvtgbyh11/ddl:v1.0.4
make deploy IMG=rfvtgbyh11/ddl:v1.0.4
