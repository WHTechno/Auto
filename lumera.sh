#!/bin/bash

set -e

# Menampilkan logo
bash logo/logowh.sh

echo "🚀 Mulai instalasi node Lumera Testnet..."

# Step 1: Update & Install dependencies
sudo apt update && sudo apt upgrade -y
sudo apt-get install git curl build-essential make jq gcc snapd chrony lz4 tmux unzip bc -y

# Step 2: Install Go
echo "📦 Menginstal Go..."
rm -rf $HOME/go
sudo rm -rf /usr/local/go
cd $HOME
curl -L https://dl.google.com/go/go1.21.5.linux-amd64.tar.gz | sudo tar -C /usr/local -zxvf -

cat <<'EOF' >>$HOME/.profile
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export GO111MODULE=on
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
EOF

source $HOME/.profile
echo "✅ Go versi: $(go version)"

# Step 3: Download & install Lumera binary
cd $HOME
wget https://github.com/LumeraProtocol/lumera/releases/download/v1.0.1/lumera_v1.0.1_linux_amd64.tar.gz
tar -xvf lumera_v1.0.1_linux_amd64.tar.gz
rm lumera_v1.0.1_linux_amd64.tar.gz install.sh
sudo mv libwasmvm.x86_64.so /usr/lib/
chmod +x lumerad

# Membuat direktori $HOME/go/bin jika belum ada
mkdir -p $HOME/go/bin
mv lumerad $HOME/go/bin/
echo "✅ Lumera versi: $(lumerad version)"

# Step 4: Inisialisasi Node
read -p "📝 Masukkan nama moniker (nama node): " MONIKER
lumerad init "$MONIKER" --chain-id=lumera-testnet-1

# Step 5: Unduh genesis & addrbook
curl -Ls https://ss-t.lumera.nodestake.org/genesis.json > $HOME/.lumera/config/genesis.json
curl -Ls https://ss-t.lumera.nodestake.org/addrbook.json > $HOME/.lumera/config/addrbook.json

# Step 6: Konfigurasi seeds dan pruning
SEEDS="10a50e7a88561b22a8d1f6f0fb0b8e54412229ab@seeds.lumera.io:26656"
sed -i -e "s|^seeds *=.*|seeds = \"$SEEDS\"|" $HOME/.lumera/config/config.toml

sed -i \
  -e 's|^pruning *=.*|pruning = "custom"|' \
  -e 's|^pruning-keep-recent *=.*|pruning-keep-recent = "100"|' \
  -e 's|^pruning-keep-every *=.*|pruning-keep-every = "0"|' \
  -e 's|^pruning-interval *=.*|pruning-interval = "19"|' \
  $HOME/.lumera/config/app.toml

# Mengatur minimum-gas-prices
sed -i -e "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0.025ulume\"/" $HOME/.lumera/config/app.toml

# Step 7: Buat systemd service
sudo tee /etc/systemd/system/lumerad.service > /dev/null <<EOF
[Unit]
Description=Lumera Daemon
After=network-online.target

[Service]
User=$USER
ExecStart=$(which lumerad) start
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable lumerad

# Step 8: Download Snapshot
echo "📦 Mengunduh snapshot..."
SNAP_NAME=$(curl -s https://ss-t.lumera.nodestake.org/ | egrep -o ">20.*\.tar.lz4" | tr -d ">")
curl -o - -L https://ss-t.lumera.nodestake.org/${SNAP_NAME} | lz4 -c -d - | tar -x -C $HOME/.lumera

# Step 9: Start Node
sudo systemctl restart lumerad
echo "✅ Node telah dimulai. Menampilkan log..."

# Step 10: Tampilkan log
sleep 2
journalctl -u lumerad -f -o cat
