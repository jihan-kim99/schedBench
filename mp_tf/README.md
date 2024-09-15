# How to deploy

## Kind

inside tf/ folder

run `kind create cluster --config kind-cluster.yaml`

this will create the cluster with 4 workers

`bash wtf.bash`

this will get the provider token also set the tfvalue

finally

`terraform apply --auto-approve`