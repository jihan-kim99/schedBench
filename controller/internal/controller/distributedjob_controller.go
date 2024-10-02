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
	"k8s.io/apimachinery/pkg/types"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/builder"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/handler"
	"sigs.k8s.io/controller-runtime/pkg/log"
	"sigs.k8s.io/controller-runtime/pkg/predicate"
	"sigs.k8s.io/controller-runtime/pkg/reconcile"

	batchv1 "custom-scheduler/api/v1"

	corev1 "k8s.io/api/core/v1"
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
	logger.Info("Reconcile running")

	// TODO(user): your logic here
	var distributedJob batchv1.DistributedJob
	if err := r.Get(ctx, req.NamespacedName, &distributedJob); err != nil {
		logger.Error(err, "Failed to fetch DistributedJob")
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	// topological sort and set Resource and Order value in WorkloadStatus
	sortedWorkloads, err := topologicalSort(distributedJob.Spec.Workloads)
	if err != nil {
		logger.Error(err, "Failed to perform topological sort")
		return ctrl.Result{}, err
	}
	distributedJob.Status.WorkloadStatuses = sortedWorkloads

	statusMap := map[string]int{
		"Running":       4,
		"Pending":       3,
		"Failed":        2,
		"Succeeded":     1,
		"Unknown":       0,
		"Not scheduled": -1,
	}

	// Pod 생성에 대한 Watcher 필요

	// Iterating workloads and check for pod statue
	for _, workload := range distributedJob.Spec.Workloads {
		// Get pods which have same resource label in same namespace CRD
		var podList corev1.PodList
		if err := r.List(ctx, &podList, client.MatchingLabels{"resource": workload.Resource}, client.InNamespace(distributedJob.Namespace)); err != nil {
			logger.Error(err, "Failed to list pods for workload", "workload", workload.Resource)
			continue
		}
		if len(podList.Items) == 0 {
			logger.Info("No pods assigned for workload", "workload", workload.Resource)
			continue
		}

		// Get according WorkloadStatus (idx)
		var idx int = -1
		for i, _ := range distributedJob.Status.WorkloadStatuses {
			if distributedJob.Status.WorkloadStatuses[i].Resource == workload.Resource {
				idx = i
				break
			}
		}

		// Assign Pods for WorkloadStatus
		for _, pod := range podList.Items {
			podScheduling := batchv1.PodScheduling{
				PodName:  pod.Name,
				NodeName: pod.Spec.NodeName,
			}

			distributedJob.Status.WorkloadStatuses[idx].SchedulingInfo = append(distributedJob.Status.WorkloadStatuses[idx].SchedulingInfo, podScheduling)
			if statusMap[distributedJob.Status.WorkloadStatuses[idx].Phase] < statusMap[getPodPhase(pod.Status.Phase)] {
				distributedJob.Status.WorkloadStatuses[idx].Phase = getPodPhase(pod.Status.Phase)
			}
			logger.Info("New pod assigned", "podName", pod.Name)
		}
	}

	if err := r.Status().Update(ctx, &distributedJob); err != nil {
		return ctrl.Result{}, err
	}

	return ctrl.Result{}, nil
}

func topologicalSort(workloads []batchv1.Workload) ([]batchv1.WorkloadStatus, error) {
	inDegree := make(map[string]int)   // 각 Workload의 in-degree 카운트
	graph := make(map[string][]string) // 각 Workload 간의 의존 관계 그래프
	queue := []string{}
	result := []batchv1.WorkloadStatus{}
	order := 1

	// Initailization
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
				result = append(result, batchv1.WorkloadStatus{
					Resource:       workload.Resource,
					Order:          order,
					Phase:          "Not scheduled",
					SchedulingInfo: []batchv1.PodScheduling{},
				})
				order++
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

// Helper function to map PodPhase to string phase
func getPodPhase(podPhase corev1.PodPhase) string {
	switch podPhase {
	case corev1.PodPending:
		return "Pending"
	case corev1.PodRunning:
		return "Running"
	case corev1.PodSucceeded:
		return "Succeeded"
	case corev1.PodFailed:
		return "Failed"
	default:
		return "Unknown"
	}
}

// SetupWithManager sets up the controller with the Manager.
func (r *DistributedJobReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&batchv1.DistributedJob{}).
		Watches(
			&corev1.Pod{}, // Pod 리소스 감시
			handler.EnqueueRequestsFromMapFunc(r.findObjectsForPod),
			builder.WithPredicates(predicate.ResourceVersionChangedPredicate{}),
		).
		Complete(r)
}

func (r *DistributedJobReconciler) findObjectsForPod(ctx context.Context, pod client.Object) []reconcile.Request {
	attachedDistributedJobs := &batchv1.DistributedJobList{}
	listOps := &client.ListOptions{
		Namespace: pod.GetNamespace(),
	}

	err := r.List(ctx, attachedDistributedJobs, listOps)
	if err != nil {
		return []reconcile.Request{}
	}

	requests := make([]reconcile.Request, len(attachedDistributedJobs.Items))
	for i, item := range attachedDistributedJobs.Items {
		requests[i] = reconcile.Request{
			NamespacedName: types.NamespacedName{
				Name:      item.GetName(),
				Namespace: item.GetNamespace(),
			},
		}
	}
	return requests
}
