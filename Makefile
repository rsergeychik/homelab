SHELL := /bin/bash

wg-server-keypair:
	private_key=$$(wg genkey); \
	echo -n "$$private_key" | ansible-vault encrypt_string --name 'wg_server_private_key'; \
	echo "$$private_key" | wg pubkey \

wg-client-keypair:
	private_key=$$(wg genkey); \
	echo -n "$$private_key" | ansible-vault encrypt_string --name 'wg_client_private_key'; \
	echo "$$private_key" | wg pubkey \
