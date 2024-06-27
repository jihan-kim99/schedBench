# kind cluster create

kind create cluster --config mnist-cluster.yaml

# docker image build

docker build -t mnist .
docker tag mnist:latest <userName>/mnist:latest
docker push <userName>/mnist:latest

> Before push need to login via `docker login`