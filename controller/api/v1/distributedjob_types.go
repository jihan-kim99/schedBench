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

package v1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// EDIT THIS FILE!  THIS IS SCAFFOLDING FOR YOU TO OWN!
// NOTE: json tags are required.  Any new fields you add must have json tags for the fields to be serialized.

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status

// DistributedJob is the Schema for the distributedjobs API
type DistributedJob struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   DistributedJobSpec   `json:"spec,omitempty"`
	Status DistributedJobStatus `json:"status,omitempty"`
}

// DistributedJobSpec defines the desired state of DistributedJob
type DistributedJobSpec struct {
	// INSERT ADDITIONAL SPEC FIELDS - desired state of cluster
	// Important: Run "make" to regenerate code after modifying this file

	Workloads []Workload `json:"workloads,omitempty"`
}

// Workload defines a single workload in the DistributedJob
type Workload struct {
	Resource     string       `json:"resource"`
	Dependencies []Dependency `json:"dependencies,omitempty"`
}

// Dependency defines a dependency for a workload
type Dependency struct {
	Resource     string `json:"resource"`
	MinBandwidth int    `json:"minBandwidth,omitempty"`
	MaxLatency   int    `json:"maxLatency,omitempty"`
}

// DistributedJobStatus defines the observed state of DistributedJob
type DistributedJobStatus struct {
	// 각 워크로드 리소스의 상태를 저장하는 리스트
	WorkloadStatuses []WorkloadStatus `json:"workloadStatuses,omitempty"`
}

// WorkloadStatus defines the status of a single workload in the DistributedJob
type WorkloadStatus struct {
	Resource       string          `json:"resource"`                 // 워크로드 리소스 이름
	Order          int             `json:"order"`                    // 스케줄링되는 순서
	Phase          string          `json:"phase,omitempty"`          // 현재 상태 (예: Not Pending, Running, Succeeded, Failed, Unknown)
	SchedulingInfo []PodScheduling `json:"schedulingInfo,omitempty"` // 스케줄링된 리소스의 Pod 이름
}

// PodScheduling defines current scheuling status of the Resource
type PodScheduling struct {
	PodName  string `json:"podName,omitempty"`
	NodeName string `json:"nodeName,omitempty"`
}

// +kubebuilder:object:root=true

// DistributedJobList contains a list of DistributedJob
type DistributedJobList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []DistributedJob `json:"items"`
}

func init() {
	SchemeBuilder.Register(&DistributedJob{}, &DistributedJobList{})
}
