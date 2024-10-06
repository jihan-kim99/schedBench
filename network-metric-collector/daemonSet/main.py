import os
import requests
import json
import asyncio
import logging
from flask import Flask, jsonify, request
from kubernetes import client, config
from hypercorn.asyncio import serve
from hypercorn.config import Config

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

app = Flask(__name__)

master_url = os.getenv('MASTER_SERVER_URL')
node_name = os.getenv('NODE_NAME')
pod_ip = os.getenv('POD_IP')

def register_to_master():
    data = {"node_name": node_name, "pod_ip": pod_ip}
    try:
        response = requests.post(f"{master_url}/register", json=data)
        if response.status_code == 200:
            logging.info(f"Registered {node_name} with IP {pod_ip} to the master")
        else:
            logging.error(f"Failed to register with master. Status code: {response.status_code}")
    except Exception as e:
        logging.error(f"Error registering with master: {str(e)}")

config.load_incluster_config()
v1 = client.CoreV1Api()

def get_all_node_ips():
    try:
        nodes = v1.list_node()
        return [address.address for node in nodes.items for address in node.status.addresses if address.type == "InternalIP"]
    except Exception as e:
        logging.error(f"Error getting node IPs: {str(e)}")
        return []

async def run_iperf3_bandwidth(target_ip):
    try:
        proc = await asyncio.create_subprocess_exec(
            'iperf3', '-c', target_ip, '-J', '-t', '5',
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        stdout, _ = await proc.communicate()
        data = json.loads(stdout)
        bits_per_second = data['end']['streams'][0]['sender']['bits_per_second']
        return round(bits_per_second / 1000000, 2)
    except Exception as e:
        logging.error(f"Error running iperf3 bandwidth test to {target_ip}: {str(e)}")
        return None

async def run_ping_latency(target_ip, count=5):
    try:
        proc = await asyncio.create_subprocess_exec(
            'ping', '-c', str(count), '-q', target_ip,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        stdout, _ = await proc.communicate()
        output_lines = stdout.decode().split('\n')
        for line in output_lines:
            if "rtt min/avg/max/mdev" in line:
                rtt_stats = line.split('=')[1].strip().split('/')
                return round(float(rtt_stats[1]), 2)
        raise ValueError("Couldn't parse ping output")
    except asyncio.TimeoutError:
        logging.error(f"Ping to {target_ip} timed out")
    except Exception as e:
        logging.error(f"Error running ping to {target_ip}: {str(e)}")
    return None

async def collect_network_metrics(target_ips):
    tasks = []
    for ip in target_ips:
        if ip != pod_ip:
            tasks.append(run_iperf3_bandwidth(ip))
            tasks.append(run_ping_latency(ip))
    results = await asyncio.gather(*tasks)
    logging.info(f"Collected metrics: {results}")
    metrics = {}
    for i in range(0, len(results), 2):
        ip = target_ips[i // 2]
        metrics[ip] = {
            'bandwidth_mbps': results[i],
            'latency': results[i + 1]
        }
    return metrics

@app.route('/collect_metrics', methods=['POST'])
async def collect_metrics():
    target_ips = request.json.get('target_ips', [])
    metrics = await collect_network_metrics(target_ips)
    return jsonify(metrics)

if __name__ == "__main__":
    register_to_master()
    
    config = Config()
    config.bind = ["0.0.0.0:8080"]
    asyncio.run(serve(app, config))