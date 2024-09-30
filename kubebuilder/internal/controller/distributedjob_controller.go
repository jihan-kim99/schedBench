/*
Copyright 2024.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package controller

import (
	"context"
	"fmt"

	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/log"

	batchv1 "custom-scheduler/api/v1"
)

// DistributedJobReconciler reconciles a DistributedJob object
type DistributedJobReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

// +kubebuilder:rbac:groups=batch.ddl.com,resources=distributedjobs,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=batch.ddl.com,resources=distributedjobs/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=batch.ddl.com,resources=distributedjobs/finalizers,verbs=update

// Reconcile is part of the main kubernetes reconciliation loop which aims to
// move the current state of the cluster closer to the desired state.
// TODO(user): Modify the Reconcile function to compare the state specified by
// the DistributedJob object against the actual cluster state, and then
// perform operations to make the cluster state reflect the state specified by
// the user.
//
// For more details, check Reconcile and its Result here:
// - https://pkg.go.dev/sigs.k8s.io/controller-runtime@v0.19.0/pkg/reconcile
func (r *DistributedJobReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	logger := log.FromContext(ctx)

	// TODO(user): your logic here
	var distributedJob batchv1.DistributedJob
	if err := r.Get(ctx, req.NamespacedName, &distributedJob); err != nil {
		logger.Error(err, "Failed to fetch DistributedJob")
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	sortedWorkloads, err := topologicalSort(distributedJob.Spec.Workloads)
	if err != nil {
		logger.Error(err, "Failed to perform topological sort")
		return ctrl.Result{}, err
	}

	if len(distributedJob.Status.WorkloadStatuses) == 0 {
		for _, workload := range sortedWorkloads {
			distributedJob.Status.WorkloadStatuses = append(distributedJob.Status.WorkloadStatuses, batchv1.WorkloadStatus{
				Resource: workload.Resource,
				Order:    0, // Will be updated
				Phase:    "Not scheduled",
				PodName:  "",
				NodeName: "",
			})
		}
	}

	for order, sortedWorkload := range sortedWorkloads {
		for i, status := range distributedJob.Status.WorkloadStatuses {
			if status.Resource == sortedWorkload.Resource {
				distributedJob.Status.WorkloadStatuses[i].Order = order + 1
				distributedJob.Status.WorkloadStatuses[i].Resource = ""
				distributedJob.Status.WorkloadStatuses[i].NodeName = ""
				distributedJob.Status.WorkloadStatuses[i].Phase = "Not scheduled"
				distributedJob.Status.WorkloadStatuses[i].PodName = "p1"
				break
			}
		}
	}

	if err := r.Status().Update(ctx, &distributedJob); err != nil {
		return ctrl.Result{}, err
	}

	return ctrl.Result{}, nil
}

func topologicalSort(workloads []batchv1.Workload) ([]batchv1.Workload, error) {
	inDegree := make(map[string]int)   // 각 Workload의 in-degree 카운트
	graph := make(map[string][]string) // 각 Workload 간의 의존 관계 그래프
	queue := []string{}
	result := []batchv1.Workload{}

	for _, workload := range workloads {
		graph[workload.Resource] = nil
		inDegree[workload.Resource] = 0
	}

	for _, workload := range workloads {
		for _, dep := range workload.Dependencies {
			graph[dep.Resource] = append(graph[dep.Resource], workload.Resource)
			inDegree[workload.Resource]++
		}
	}
	for resource, degree := range inDegree {
		if degree == 0 {
			queue = append(queue, resource)
		}
	}

	// Kahn's Algorithm
	for len(queue) > 0 {
		curr := queue[0]
		queue = queue[1:]
		for _, workload := range workloads {
			if workload.Resource == curr {
				result = append(result, workload)
				break
			}
		}
		for _, neighbor := range graph[curr] {
			inDegree[neighbor]--
			if inDegree[neighbor] == 0 {
				queue = append(queue, neighbor)
			}
		}
	}

	if len(result) != len(workloads) {
		return nil, fmt.Errorf("cycle detected in dependencies")
	}
	return result, nil
}

// SetupWithManager sets up the controller with the Manager.
func (r *DistributedJobReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&batchv1.DistributedJob{}).
		Complete(r)
}
