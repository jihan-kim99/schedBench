from flask import Flask, request, jsonify
from kubernetes import client, config
import time
import requests
import threading
import logging

app = Flask(__name__)

# Load Kubernetes cluster config
config.load_incluster_config()
v1 = client.CoreV1Api()

# This will store the registered pods and their IPs
registered_nodes = {}
metrics_data = {'bandwidth': {}, 'latency': {}}
ip_to_node_map = {}

# Lock for thread-safe updates
lock = threading.Lock()

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def get_non_control_plane_node_count():
    """Get the count of non-control plane nodes in the cluster."""
    nodes = v1.list_node().items
    return sum(1 for node in nodes if 'node-role.kubernetes.io/control-plane' not in node.metadata.labels)

def collect_metrics_from_pod(pod_ip, target_ips):
    """Collect metrics from a DaemonSet pod using POST."""
    try:
        response = requests.post(f"http://{pod_ip}:8080/collect_metrics", 
                                 json={"target_ips": target_ips})
        if response.status_code == 200:
            logging.info(f"Successfully collected metrics from pod at {ip_to_node_map.get(pod_ip, pod_ip)}")
            return response.json()
        else:
            logging.warning(f"Failed to collect metrics from pod at {ip_to_node_map.get(pod_ip, pod_ip)}. Status code: {response.status_code}")
            return None
    except Exception as e:
        logging.error(f"Error collecting metrics from pod at {ip_to_node_map.get(pod_ip, pod_ip)}: {e}")
        return None

def update_crd():
    """Update or create the CRD with the collected metrics."""
    crd_data = {
        "apiVersion": "network.example.com/v1",
        "kind": "NetworkMetrics",
        "metadata": {"name": "cluster-metrics"},
        "spec": {"metrics": metrics_data}
    }

    logging.info(f"CRD data: {crd_data}")

    crd_api = client.CustomObjectsApi()
    try:
        # Try to get the existing custom resource
        crd_api.get_namespaced_custom_object(
            group="network.example.com",
            version="v1",
            namespace="kube-system",
            plural="networkmetrics",
            name="cluster-metrics"
        )
        
        # If it exists, update it
        crd_api.patch_namespaced_custom_object(
            group="network.example.com",
            version="v1",
            namespace="kube-system",
            plural="networkmetrics",
            name="cluster-metrics",
            body=crd_data
        )
        logging.info("Successfully updated existing CRD with network metrics.")
    except client.exceptions.ApiException as e:
        if e.status == 404:
            # If it doesn't exist, create it
            crd_api.create_namespaced_custom_object(
                group="network.example.com",
                version="v1",
                namespace="kube-system",
                plural="networkmetrics",
                body=crd_data
            )
            logging.info("Successfully created new CRD with network metrics.")
        else:
            logging.error(f"Failed to update or create CRD: {e}")

def poll_metrics_periodically():
    while True:
        logging.info("Polling network metrics from all registered pods...")
        all_metrics = {}
        pod_ips = list(registered_nodes.values())
        for node_name, pod_ip in registered_nodes.items():
            target_ips = [ip for ip in pod_ips if ip != pod_ip]
            pod_metrics = collect_metrics_from_pod(pod_ip, target_ips)
            if pod_metrics:
                all_metrics[node_name] = pod_metrics
        
        # Process the collected metrics
        process_metrics(all_metrics)
        update_crd()
        time.sleep(60)  # Poll every 1 minute

def process_metrics(all_metrics):
    """Process the collected metrics from all pods."""
    network_bandwidth = {}
    network_latency = {}
    
    for source_node, metrics in all_metrics.items():
        network_bandwidth[source_node] = {}
        network_latency[source_node] = {}
        
        for target_ip, data in metrics.items():
            target_node = ip_to_node_map.get(target_ip, target_ip)
            
            # Process bandwidth
            bandwidth = data.get('bandwidth_mbps')
            if bandwidth is not None:
                network_bandwidth[source_node][target_node] = bandwidth
            
            # Process latency
            latency_ms = data.get('latency')
            if isinstance(latency_ms, (int, float)):  # Ensure it's a valid number
                network_latency[source_node][target_node] = latency_ms
            else:
                logging.error(f"Invalid latency data for {source_node} -> {target_node}: {latency_ms}")
    
    # Update global metrics data with lock for thread safety
    with lock:
        metrics_data['bandwidth'] = network_bandwidth
        metrics_data['latency'] = network_latency
    
    logging.info(f"Processed network bandwidth metrics: {network_bandwidth}")
    logging.info(f"Processed network latency metrics: {network_latency}")

@app.route('/register', methods=['POST'])
def register():
    """Register a DaemonSet pod with the master."""
    node_name = request.json.get('node_name')
    pod_ip = request.json.get('pod_ip')
    
    if not node_name or not pod_ip:
        logging.warning("Received incomplete registration data.")
        return jsonify({"error": "Missing node_name or pod_ip"}), 400
    
    with lock:
        registered_nodes[node_name] = pod_ip
        ip_to_node_map[pod_ip] = node_name
    
    logging.info(f"Registered pod {node_name} with IP {pod_ip}. Total registered nodes: {len(registered_nodes)}")
    
    # Check if all expected nodes have registered
    expected_node_count = get_non_control_plane_node_count()
    if len(registered_nodes) == expected_node_count:
        logging.info(f"All expected nodes ({expected_node_count}) have registered. Starting metric collection.")
        # Start polling for metrics every 1 minute in a separate thread
        thread = threading.Thread(target=poll_metrics_periodically)
        thread.start()
    
    return jsonify({"status": "registered", "node": node_name}), 200

def wait_for_nodes():
    """Wait for all non-control plane nodes to register."""
    expected_node_count = get_non_control_plane_node_count()
    logging.info(f"Waiting for {expected_node_count} non-control plane nodes to register...")
    while True:
        with lock:
            if len(registered_nodes) == expected_node_count:
                logging.info("All expected nodes have registered.")
                return
        time.sleep(5)  # Check every 5 seconds

if __name__ == "__main__":
    # Start waiting for nodes in a separate thread
    threading.Thread(target=wait_for_nodes).start()

    # Start the Flask server to listen for registrations
    logging.info("Starting the master server for collecting network metrics.")
    app.run(host='0.0.0.0', port=8080)