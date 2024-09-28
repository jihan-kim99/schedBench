package main

import (
	"context"
	"fmt"
	"log"
	"time"

	v1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
)

func main() {
	// Create in-cluster config
	config, err := rest.InClusterConfig()
	if err != nil {
		log.Fatalf("Failed to create in-cluster config: %v", err)
	}

	// Create the Kubernetes clientset
	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		log.Fatalf("Failed to create clientset: %v", err)
	}

	for {
		// List all unscheduled pods (i.e., pods with empty NodeName)
		unscheduledPods, err := clientset.CoreV1().Pods("").List(context.TODO(), metav1.ListOptions{
			FieldSelector: "spec.nodeName=", // Select pods without a node assigned
		})
		if err != nil {
			log.Fatalf("Failed to list unscheduled pods: %v", err)
		}

		// Iterate through the unscheduled pods and assign them to a node
		for _, pod := range unscheduledPods.Items {
			fmt.Printf("Found unscheduled pod: %s\n", pod.Name)

			// Assign the pod to a specific node (example: kind-worker2)
			nodeName := "kind-worker2"

			// Call the bind API to schedule the pod
			err = bindPodToNode(clientset, &pod, nodeName)
			if err != nil {
				log.Printf("Failed to bind pod %s to node %s: %v", pod.Name, nodeName, err)
				continue
			}
			fmt.Printf("Scheduled pod %s to node %s\n", pod.Name, nodeName)
		}

		// Sleep for a while before checking again
		time.Sleep(10 * time.Second)
	}
}

// bindPodToNode binds a pod to a specific node by calling the Kubernetes API
func bindPodToNode(clientset *kubernetes.Clientset, pod *v1.Pod, nodeName string) error {
	binding := &v1.Binding{
		ObjectMeta: metav1.ObjectMeta{
			Name:      pod.Name,
			Namespace: pod.Namespace,
		},
		Target: v1.ObjectReference{
			APIVersion: "v1",
			Kind:       "Node",
			Name:       nodeName,
		},
	}

	return clientset.CoreV1().Pods(pod.Namespace).Bind(context.TODO(), binding, metav1.CreateOptions{})
}