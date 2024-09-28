# How to deploy

## Kind

inside tf/ folder

run `kind create cluster --config kind-cluster.yaml`

this will create the cluster with 4 workers

`bash wtf.bash`

this will get the provider token also set the tfvalue

finally

`terraform apply --auto-approve`

## EKS

First go to `tf_aws/cluster` folder

`terraform apply --auto-approve`

Then run `bash ctl-conf`. This will set up the `kubectl` to able to connect to the EKS and manage locally.

The go to `tf_aws/workload` folder

`terraform apply --auto-approve`

To create whole workload

## CleanUp

To clean up you need to apply `tf destroy` on `workload` then `cluster`
