#!/bin/bash

# Fungsi deteksi instalasi
is_installed() {
    command -v "$1" >/dev/null 2>&1
}

# Tampilkan logo jika ada
if [ -f "logo/logowh.sh" ]; then
    bash logo/logowh.sh
fi

# Update sistem
sudo apt-get update && sudo apt-get upgrade -y

# Install dependensi docker jika belum ada
if ! is_installed docker; then
    echo "[INFO] Installing Docker..."
    sudo apt-get install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
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

# Install drosera
if ! is_installed droseraup; then
    echo "[INFO] Installing Drosera CLI..."
    curl -L https://app.drosera.io/install | bash
    export PATH="$HOME/.drosera/bin:$PATH"
    source ~/.bashrc
    droseraup
else
    echo "[INFO] Drosera CLI sudah terinstal."
fi

# Install Foundry
if ! is_installed forge; then
    echo "[INFO] Installing Foundry..."
    curl -L https://foundry.paradigm.xyz | bash
    export PATH="$HOME/.foundry/bin:$PATH"
    foundryup
else
    echo "[INFO] Foundry sudah terinstal."
fi

# Install Bun
if ! is_installed bun; then
    echo "[INFO] Installing Bun..."
    curl -fsSL https://bun.sh/install | bash
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
    source ~/.bashrc
else
    echo "[INFO] Bun sudah terinstal."
fi

# Konfigurasi Git
read -p "Masukkan Email GitHub Anda: " github_email
read -p "Masukkan Username GitHub Anda: " github_username
git config --global user.email "$github_email"
git config --global user.name "$github_username"

# Inisialisasi proyek
mkdir -p $HOME/my-drosera-trap && cd $HOME/my-drosera-trap
forge init -t drosera-network/trap-foundry-template
bun install
forge build

# Edit drosera.toml
echo "[INFO] Silakan masukkan EVM Private Key Anda saat mengedit."
read -p "Tekan ENTER untuk edit drosera.toml..."
nano drosera.toml

# Terapkan konfigurasi Drosera
echo "[INFO] Menjalankan drosera apply..."
read -p "Masukkan PRIVATE KEY EVM Anda: " evm_pk
DROSERA_PRIVATE_KEY=$evm_pk drosera apply

# Pull docker image
docker pull ghcr.io/drosera-network/drosera-operator:latest

# Edit docker-compose.yaml
mkdir -p $HOME/Drosera-Network && cd $HOME/Drosera-Network
echo "[INFO] Silakan masukkan ETH_PRIVATE_KEY dan VPS_IP Anda saat mengedit docker-compose.yaml"
read -p "Tekan ENTER untuk edit docker-compose.yaml..."
nano docker-compose.yaml

# Jalankan docker
docker compose up -d

# Firewall rules
sudo ufw allow ssh
sudo ufw allow 22
sudo ufw allow 31313/tcp
sudo ufw allow 31314/tcp
sudo ufw --force enable

echo "✅ Instalasi dan konfigurasi selesai!"
