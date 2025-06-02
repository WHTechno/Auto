#!/bin/bash

set -e

# Tampilkan logo jika ada
if [ -f "logo/logowh.sh" ]; then
  bash logo/logowh.sh
fi

# Fungsi untuk cek apakah perintah tersedia
is_installed() {
  command -v "$1" &> /dev/null
}

# Update sistem
sudo apt-get update && sudo apt-get upgrade -y

# Install Docker jika belum terpasang
if ! is_installed docker; then
  echo "[INFO] Menginstal Docker..."
  sudo apt-get install -y ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o docker.asc
  sudo mv docker.asc /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
  echo "[INFO] Docker sudah terinstal."
fi

# Install Drosera CLI
if ! is_installed drosera; then
  curl -L https://app.drosera.io/install | bash
  source ~/.bashrc
fi

# Install Foundry
if ! is_installed forge; then
  curl -L https://foundry.paradigm.xyz | bash
  source ~/.bashrc
  foundryup
fi

# Install Bun
if ! is_installed bun; then
  curl -fsSL https://bun.sh/install | bash
  source ~/.bashrc
fi

# Setup git global config
read -p "Masukkan Email GitHub Anda: " github_email
read -p "Masukkan Username GitHub Anda: " github_user

git config --global user.email "$github_email"
git config --global user.name "$github_user"

# Clone & init Drosera Trap project
mkdir -p $HOME/my-drosera-trap
cd $HOME/my-drosera-trap
forge init -t drosera-network/trap-foundry-template
source ~/.bashrc
bun install
forge build

# Konfigurasi drosera.toml
read -p "Masukkan ETH Address untuk whitelist: " eth_address
read -p "Masukkan EVM Private Key untuk drosera apply: " evm_pk

cat <<EOF > drosera.toml
ethereum_rpc = "https://rpc-holesky.rockx.com"
drosera_rpc = "https://relay.testnet.drosera.io"
eth_chain_id = 17000
drosera_address = "0xea08f7d533C2b9A62F40D5326214f39a8E3A32F8"

[traps]

[traps.mytrap]
path = "out/HelloWorldTrap.sol/HelloWorldTrap.json"
response_contract = "0xdA890040Af0533D98B9F5f8FE3537720ABf83B0C"
response_function = "helloworld(string)"
cooldown_period_blocks = 33
min_number_of_operators = 1
max_number_of_operators = 2
block_sample_size = 10
private = true
whitelist = ["$eth_address"]
address = "TRAP CONFIG ADDRESS 1"

[traps.mytrap2]
path = "out/HelloWorldTrap.sol/HelloWorldTrap.json"
response_contract = "0xdA890040Af0533D98B9F5f8FE3537720ABf83B0C"
response_function = "helloworld(string)"
cooldown_period_blocks = 33
min_number_of_operators = 1
max_number_of_operators = 2
block_sample_size = 10
private_trap = true
whitelist = ["$eth_address"]
address = "TRAP CONFIG ADDRESS 2"
EOF

DROSERA_PRIVATE_KEY=$evm_pk drosera apply

# Setup docker-compose Drosera Operator
read -p "Masukkan VPS IP (untuk network-external-p2p-address): " vps_ip

mkdir -p $HOME/Drosera-Network
cd $HOME/Drosera-Network

cat <<EOF > docker-compose.yaml
version: '3'
services:
  drosera1:
    image: ghcr.io/drosera-network/drosera-operator:latest
    container_name: drosera-node1
    network_mode: host
    volumes:
      - drosera_data1:/data
    command: node --db-file-path /data/drosera.db --network-p2p-port 31313 --server-port 31314 --eth-rpc-url https://rpc-holesky.rockx.com --eth-backup-rpc-url https://holesky.drpc.org --drosera-address 0xea08f7d533C2b9A62F40D5326214f39a8E3A32F8 --eth-private-key ${evm_pk} --listen-address 0.0.0.0 --network-external-p2p-address ${vps_ip} --disable-dnr-confirmation true
    restart: always

  drosera2:
    image: ghcr.io/drosera-network/drosera-operator:latest
    container_name: drosera-node2
    network_mode: host
    volumes:
      - drosera_data2:/data
    command: node --db-file-path /data/drosera.db --network-p2p-port 31315 --server-port 31316 --eth-rpc-url https://rpc-holesky.rockx.com --eth-backup-rpc-url https://holesky.drpc.org --drosera-address 0xea08f7d533C2b9A62F40D5326214f39a8E3A32F8 --eth-private-key ${evm_pk} --listen-address 0.0.0.0 --network-external-p2p-address ${vps_ip} --disable-dnr-confirmation true
    restart: always

volumes:
  drosera_data1:
  drosera_data2:
EOF

# Pull docker image jika belum
docker pull ghcr.io/drosera-network/drosera-operator:latest

# Aktifkan UFW + izinkan port
sudo ufw allow ssh
sudo ufw allow 22
sudo ufw allow 31313/tcp
sudo ufw allow 31314/tcp
sudo ufw --force enable

# Jalankan node
docker compose up -d

echo "[SELESAI] Drosera node berhasil disiapkan dan dijalankan!"
