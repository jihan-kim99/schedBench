import os
import socket
import time

# Get the environment variables
env_vars = os.environ

# Check if the value is 0
if '0' in env_vars.values():
    with open('/mnt/data/ip', 'w') as file:
        ip_address = socket.gethostbyname(socket.gethostname())
        file.write(ip_address)
else:
    # Wait until the IP address is written to the file
    while not os.path.exists('/mnt/data/ip'):
        time.sleep(1)

        # Get the IP address
        ip_address = socket.gethostbyname(socket.gethostname())
        # Write the IP address to the environment variable
        os.environ['MASTER_ADDR'] = ip_address
        print(f'IP Address: {ip_address}')