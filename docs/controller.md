make generate && make manifests && make install
k apply -f clusterRole.yaml
<!-- make docker-build docker-push IMG=jinnkenny99/ddl:v1.0.14 -->
make deploy IMG=jinnkenny99/ddl:v1.0.14
