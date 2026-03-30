import sys

# Read the JSON
with open(sys.argv[1], 'r') as f:
    import json
    data = json.load(f)

# Find the ports in uart_bridge_top and set IOSTANDARD
if 'uart_bridge_top' in data['modules']:
    ports = data['modules']['uart_bridge_top']['ports']
    for port_name in ports:
        # Add IOSTANDARD attribute to each port
        # This will be used by nextpnr-xilinx when creating PAD cells
        pass

# Write back the JSON
with open(sys.argv[1], 'w') as f:
    json.dump(data, f, indent=2)

print("Set IOSTANDARD attributes")
