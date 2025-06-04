#!/bin/bash

set -e

bash logo/logowh.sh

echo -e "\n\e[1;32m🔧 EMPE Chain Auto Installer (v0.4.0)\e[0m"
read -p "Masukkan Nama Moniker Node Anda: " MONIKER
echo ""

# Update & install dependencies
sudo apt update && sudo apt upgrade -y
sudo apt install curl git wget htop tmux build-essential jq make lz4 gcc unzip -y

# Install Go
cd $HOME
GO_VER="1.23.4"
wget "https://golang.org/dl/go$GO_VER.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go$GO_VER.linux-amd64.tar.gz"
rm "go$GO_VER.linux-amd64.tar.gz"
[ ! -f ~/.bash_profile ] && touch ~/.bash_profile
echo "export PATH=$PATH:/usr/local/go/bin:~/go/bin" >> ~/.bash_profile
source ~/.bash_profile
[ ! -d ~/go/bin ] && mkdir -p ~/go/bin

# Install empe-chain v0.4.0
cd $HOME
mkdir -p $HOME/.empe-chain/cosmovisor/upgrades/v0.4.0/bin
wget https://github.com/empe-io/empe-chain-releases/raw/master/v0.4.0/emped_v0.4.0_linux_amd64.tar.gz
tar -xvf emped_v0.4.0_linux_amd64.tar.gz
rm -rf emped_v0.4.0_linux_amd64.tar.gz
chmod +x emped
mv emped $HOME/.empe-chain/cosmovisor/upgrades/v0.4.0/bin

# Cosmovisor setup
sudo ln -sfn $HOME/.empe-chain/cosmovisor/upgrades/v0.4.0 $HOME/.empe-chain/cosmovisor/current
sudo ln -sfn $HOME/.empe-chain/cosmovisor/current/bin/emped /usr/local/bin/emped
go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@v1.6.0

# Install wasmvm lib
mkdir -p $HOME/.empe-chain/lib
wget "https://github.com/CosmWasm/wasmvm/releases/download/v1.5.2/libwasmvm.x86_64.so" -O "$HOME/.empe-chain/lib/libwasmvm.x86_64.so"
echo "alias emped='LD_LIBRARY_PATH=/root/.empe-chain/lib:\$LD_LIBRARY_PATH /usr/local/bin/emped'" >> ~/.bashrc
source ~/.bashrc

# Create systemd service
sudo tee /etc/systemd/system/emped.service > /dev/null << EOF
[Unit]
Description=empe-chain node service
After=network-online.target

[Service]
User=$USER
ExecStart=$(which cosmovisor) run start
Restart=on-failure
RestartSec=10
LimitNOFILE=65535
Environment="DAEMON_HOME=$HOME/.empe-chain"
Environment="DAEMON_NAME=emped"
Environment="UNSAFE_SKIP_BACKUP=true"
Environment="PATH=$PATH:$HOME/.empe-chain/cosmovisor/current/bin"
Environment="LD_LIBRARY_PATH=$HOME/.empe-chain/lib:$LD_LIBRARY_PATH"

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable emped

# Init Node
emped init "$MONIKER" --chain-id empe-testnet-2

# Download genesis and addrbook
wget -O $HOME/.empe-chain/config/genesis.json "https://raw.githubusercontent.com/empe-io/empe-chains/master/testnet-2/genesis.json"
wget -O $HOME/.empe-chain/config/addrbook.json "https://raw.githubusercontent.com/MictoNode/empe-chain/main/addrbook.json"

# Gas & pruning
sed -i.bak -e "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0.0001uempe\"/" $HOME/.empe-chain/config/app.toml
sed -i -e "s/^pruning *=.*/pruning = \"custom\"/" $HOME/.empe-chain/config/app.toml
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"100\"/" $HOME/.empe-chain/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"10\"/" $HOME/.empe-chain/config/app.toml
sed -i "s/^indexer *=.*/indexer = \"null\"/" $HOME/.empe-chain/config/config.toml

# Reset node
emped tendermint unsafe-reset-all --home $HOME/.empe-chain --keep-addr-book

# Snapshot
echo -e "\n🔄 Downloading latest snapshot..."
SNAPSHOT_URL="https://server-5.itrocket.net/testnet/empeiria/"
LATEST_SNAPSHOT=$(curl -s $SNAPSHOT_URL | grep -oP 'empeiria_\d{4}-\d{2}-\d{2}_\d+_snap\.tar\.lz4' | sort | tail -n 1)

if [ -n "$LATEST_SNAPSHOT" ]; then
  curl "$SNAPSHOT_URL$LATEST_SNAPSHOT" | lz4 -dc - | tar -xf - -C $HOME/.empe-chain
else
  echo "❌ Snapshot tidak ditemukan"
fi

# Default ports & chain settings
CUSTOM_PORT="111"
echo "export CUSTOM_PORT=$CUSTOM_PORT" >> ~/.bash_profile
source ~/.bash_profile

sed -i.bak -e "s%:1317%:${CUSTOM_PORT}17%g;
s%:8080%:${CUSTOM_PORT}80%g;
s%:9090%:${CUSTOM_PORT}90%g;
s%:9091%:${CUSTOM_PORT}91%g;
s%:8545%:${CUSTOM_PORT}45%g;
s%:8546%:${CUSTOM_PORT}46%g;
s%:6065%:${CUSTOM_PORT}65%g" $HOME/.empe-chain/config/app.toml

sed -i.bak -e "s%:26658%:${CUSTOM_PORT}58%g;
s%:26657%:${CUSTOM_PORT}57%g;
s%:6060%:${CUSTOM_PORT}60%g;
s%:26656%:${CUSTOM_PORT}56%g;
s%^external_address = \"\"%external_address = \"$(wget -qO- eth0.me):${CUSTOM_PORT}56\"%;
s%:26660%:${CUSTOM_PORT}60%g" $HOME/.empe-chain/config/config.toml

sed -i -e "s|^node *=.*|node = \"tcp://localhost:${CUSTOM_PORT}57\"|" $HOME/.empe-chain/config/client.toml
sed -i -e '/^chain-id = /c\chain-id = "empe-testnet-2"' $HOME/.empe-chain/config/client.toml
sed -i -e '/^keyring-backend = /c\keyring-backend = "test"' $HOME/.empe-chain/config/client.toml

# Peers
PEERS="edfc10bbf28b5052658b3b8b901d7d0fc25812a0@193.70.45.145:26656,4bd60dee1cb81cb544f545589b8dd286a7b3fd65@149.202.73.140:26656"
sed -i -e "s/^seeds *=.*/seeds = \"\"/" $HOME/.empe-chain/config/config.toml
sed -i -e "s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.empe-chain/config/config.toml

echo -e "\n✅ Instalasi Selesai! Jalankan node dengan:\n"
echo -e "\e[1;34msudo systemctl start emped && sudo journalctl -fu emped -o cat\e[0m"
