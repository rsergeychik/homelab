#!/bin/bash

# WireGuard Setup Script
# Usage: ./scripts/wg-setup.sh <client> <server>

set -e

CLIENT="$1"
SERVER="$2"

if [ -z "$CLIENT" ] || [ -z "$SERVER" ]; then
    echo "Error: CLIENT and SERVER parameters are required"
    echo "Usage: $0 <client> <server>"
    echo "Example: $0 rpi4 racknerd-micro-1"
    exit 1
fi

CLIENT_FILE="inventory/host_vars/${CLIENT}.yml"
SERVER_FILE="inventory/host_vars/${SERVER}.yml"

# Check if files exist
if [ ! -f "$CLIENT_FILE" ]; then
    echo "Error: Client file $CLIENT_FILE not found"
    exit 1
fi

if [ ! -f "$SERVER_FILE" ]; then
    echo "Error: Server file $SERVER_FILE not found"
    exit 1
fi

echo "🔑 Generating WireGuard keypair for client: $CLIENT"

# Generate keypair
PRIVATE_KEY=$(wg genkey)
PUBLIC_KEY=$(echo "$PRIVATE_KEY" | wg pubkey)

echo "   Generated public key: $PUBLIC_KEY"

# Get client's WireGuard IP address
CLIENT_IP=$(grep "^wg_client_address:" "$CLIENT_FILE" | sed 's/^wg_client_address: *//; s/"//g; s/\/[0-9]*//')
if [ -z "$CLIENT_IP" ]; then
    echo "Error: Could not find wg_client_address in $CLIENT_FILE"
    exit 1
fi
echo "   Client IP: $CLIENT_IP"

# Create encrypted private key
echo "📝 Encrypting private key..."
ENCRYPTED_KEY=$(echo -n "$PRIVATE_KEY" | ansible-vault encrypt_string --stdin-name 'wg_client_private_key' 2>/dev/null)

# Update client file
echo "📄 Updating $CLIENT_FILE..."

# Create a backup
cp "$CLIENT_FILE" "${CLIENT_FILE}.bak"

# Use Python to update the client file
python3 << EOF
import sys

with open('${CLIENT_FILE}', 'r') as f:
    lines = f.readlines()

# Find and remove existing wg_client_private_key
new_lines = []
skip = False
for i, line in enumerate(lines):
    if line.startswith('wg_client_private_key:'):
        skip = True
        continue
    elif skip and line.startswith('  '):
        continue
    elif skip and not line.startswith('  '):
        skip = False
    
    if not skip:
        new_lines.append(line)

# Find position to insert new key (after wg_client_address)
insert_pos = len(new_lines)
for i, line in enumerate(new_lines):
    if line.startswith('wg_client_address:'):
        insert_pos = i + 1
        break

# Insert the encrypted key
encrypted_lines = '''${ENCRYPTED_KEY}'''.split('\n')
for j, enc_line in enumerate(encrypted_lines):
    new_lines.insert(insert_pos + j, enc_line + '\n')

# Write back
with open('${CLIENT_FILE}', 'w') as f:
    f.writelines(new_lines)

print("   ✓ Updated private key")
EOF

# Update server file
echo "📄 Updating $SERVER_FILE..."

# Use Python to update server peer configuration
python3 << EOF
import sys

with open('${SERVER_FILE}', 'r') as f:
    lines = f.readlines()

# Check if wg_peers exists
has_peers = False
for line in lines:
    if line.startswith('wg_peers:'):
        has_peers = True
        break

if not has_peers:
    lines.append('\nwg_peers:\n')

# Find and update or add peer
peer_updated = False
new_lines = []
skip_next = 0

for i, line in enumerate(lines):
    if skip_next > 0:
        skip_next -= 1
        continue
    
    if '  - name: "${CLIENT}"' in line or '  - name: ${CLIENT}' in line:
        # Found existing peer, replace it
        new_lines.append('  - name: "${CLIENT}"\n')
        new_lines.append('    public_key: ${PUBLIC_KEY}\n')
        new_lines.append('    allowed_ips: "${CLIENT_IP}/32"\n')
        skip_next = 2  # Skip the old public_key and allowed_ips lines
        peer_updated = True
        print("   ✓ Updated existing peer")
    else:
        new_lines.append(line)

# If peer wasn't found, add it
if not peer_updated:
    # Find wg_peers section and add to it
    for i in range(len(new_lines)):
        if new_lines[i].startswith('wg_peers:'):
            # Insert after wg_peers:
            new_lines.insert(i + 1, '  - name: "${CLIENT}"\n')
            new_lines.insert(i + 2, '    public_key: ${PUBLIC_KEY}\n')
            new_lines.insert(i + 3, '    allowed_ips: "${CLIENT_IP}/32"\n')
            print("   ✓ Added new peer")
            break

with open('${SERVER_FILE}', 'w') as f:
    f.writelines(new_lines)
EOF

echo ""
echo "✅ Successfully configured WireGuard for $CLIENT -> $SERVER"
echo "   Client private key: Encrypted in $CLIENT_FILE"
echo "   Client public key: $PUBLIC_KEY"
echo "   Server peer config: Updated in $SERVER_FILE"
echo ""
echo "🚀 To deploy: ansible-playbook -i inventory/hosts.yml playbook.yml"