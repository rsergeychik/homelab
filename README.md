### For hosts with externally managed python installation:
```bash
sudo apt install python3-venv
sudo mkdir /opt/ansible_venv
cd /opt
sudo python3 -m venv ansible_venv
```


### Generate tls certificate:
```bash
# Generate the CA private key
openssl genrsa -out ca.key 4096

# Generate the self-signed CA certificate (valid for 365 days)
openssl req -x509 -new -nodes -key ca.key -sha256 -days 365 -out ca.crt -subj "/CN=My Awesome CA"

# Generate the client's private key
openssl genrsa -out client.key 4096

# Create a CSR for the client certificate
# The CN (Common Name) can be a username or any identifier.
openssl req -new -key client.key -out client.csr -subj "/CN=macos-user-dave"

# Use the CA to sign the client's CSR, creating the final client certificate
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days 360 -sha256

# You will be prompted to create an export password. Remember it!
openssl pkcs12 -export -out client.p12 -inkey client.key -in client.crt -certfile ca.crt
```

in Caddyfile
```caddyfile
secure.your-domain.com {
    reverse_proxy localhost:8080

    tls {
        client_auth {
            mode require_and_verify
            trusted_ca_cert_file /path/to/your/certs/ca.crt
        }
    }
}
```

client.p12 goes to the client machine.
