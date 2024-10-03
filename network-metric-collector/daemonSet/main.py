import requests
import os
import json
import subprocess
from flask import Flask, jsonify, request
from kubernetes import client, config
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

app = Flask(__name__)

master_url = os.getenv('MASTER_SERVER_URL')
node_name = os.getenv('NODE_NAME')
pod_ip = os.getenv('POD_IP')  # Assume the pod's IP is passed via environment variable

# Register the DaemonSet pod with the master
def register_to_master():
    data = {"node_name": node_name, "pod_ip": pod_ip}
    response = requests.post(f"{master_url}/register", json=data)
    if response.status_code == 200:
        print(f"Registered {node_name} with IP {pod_ip} to the master")

# Load Kubernetes config from inside the pod
config.load_incluster_config()
v1 = client.CoreV1Api()

# Function to get all nodes' internal IPs
def get_all_node_ips():
    """Query the Kubernetes API to get all nodes' internal IP addresses."""
    nodes = v1.list_node()
    node_ips = []
    
    for node in nodes.items:
        for address in node.status.addresses:
            if address.type == "InternalIP":
                node_ips.append(address.address)
    
    return node_ips

def run_iperf3_bandwidth(target_ip):
    try:
        result = subprocess.run(['iperf3', '-c', target_ip, '-J', '-t', '5'], capture_output=True, text=True)
        data = json.loads(result.stdout)
        bits_per_second = data['end']['streams'][0]['sender']['bits_per_second']
        return round(bits_per_second / 1000000, 2)  # Convert to Mbps and round to 2 decimal places
    except Exception as e:
        return f"Error running iperf3 bandwidth test to {target_ip}: {str(e)}"
    
def run_ping_latency(target_ip, count=5):
    try:
        # Run ping command
        result = subprocess.run(['ping', '-c', str(count), '-q', target_ip], capture_output=True, text=True, timeout=10)
        
        # Parse the output
        output_lines = result.stdout.split('\n')
        for line in output_lines:
            if "rtt min/avg/max/mdev" in line:
                # Extract average RTT
                rtt_stats = line.split('=')[1].strip().split('/')
                avg_latency = float(rtt_stats[1])
                return round(avg_latency, 2)  # Return average latency in ms
        raise ValueError("Couldn't parse ping output")
    except subprocess.TimeoutExpired:
        logging.error(f"Ping to {target_ip} timed out")
        return None
    except Exception as e:
        logging.error(f"Error running ping to {target_ip}: {str(e)}")
        return None

def collect_network_metrics(target_ips):
    """Collect network metrics using iperf3 for specified target IPs."""
    metrics = {}
    
    for ip in target_ips:
        if ip != pod_ip:  # Don't test against self
            bandwidth = run_iperf3_bandwidth(ip)
            latency = run_ping_latency(ip)
            metrics[ip] = {
                'bandwidth_mbps': bandwidth,
                'latency': latency
            }
    
    return metrics

@app.route('/collect_metrics', methods=['POST'])
def collect_metrics():
    """API endpoint that collects and returns network metrics for specified targets."""
    target_ips = request.json.get('target_ips', [])
    metrics = collect_network_metrics(target_ips)
    return jsonify(metrics)

if __name__ == "__main__":
    # Register the DaemonSet pod with the master server
    register_to_master()
    # Run the Flask server to expose the /collect_metrics endpoint
    app.run(host='0.0.0.0', port=8080)