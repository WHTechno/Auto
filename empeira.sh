#!/bin/bash

set -e

clear
bash logo/logowh.sh

echo -e "\n\e[1;32m🔧 EMPE Chain Installer Menu\e[0m"
echo -e "1. Install dari awal (v0.4.0)"
echo -e "2. Upgrade dari v0.3.0 ke v0.4.0"
echo -ne "\nPilih opsi [1 atau 2]: "; read OPTION

if [ "$OPTION" == "1" ]; then
  read -p "Masukkan Nama Moniker Node Anda: " MONIKER
  echo ""
  
  # Full Clean Install Script
  sudo apt update && sudo apt upgrade -y
  sudo apt install curl git wget htop tmux build-essential jq make lz4 gcc unzip -y

  # Install Go
  cd $HOME
  GO_VER="1.23.4"
  wget "https://golang.org/dl/go$GO_VER.linux-amd64.tar.gz"
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf "go$GO_VER.linux-amd64.tar.gz"
  rm "go$GO_VER.linux-amd64.tar.gz"
  echo "export PATH=$PATH:/usr/local/go/bin:~/go/bin" >> ~/.bash_profile
  source ~/.bash_profile

  # Install empe-chain v0.4.0
  cd $HOME
  mkdir -p $HOME/.empe-chain/cosmovisor/upgrades/v0.4.0/bin
  wget https://github.com/empe-io/empe-chain-releases/raw/master/v0.4.0/emped_v0.4.0_linux_amd64.tar.gz
  tar -xvf emped_v0.4.0_linux_amd64.tar.gz
  rm emped_v0.4.0_linux_amd64.tar.gz
  chmod +x emped
  mv emped $HOME/.empe-chain/cosmovisor/upgrades/v0.4.0/bin

  sudo ln -sfn $HOME/.empe-chain/cosmovisor/upgrades/v0.4.0 $HOME/.empe-chain/cosmovisor/current
  sudo ln -sfn $HOME/.empe-chain/cosmovisor/current/bin/emped /usr/local/bin/emped

  go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@v1.6.0

  # Lib wasm
  mkdir -p $HOME/.empe-chain/lib
  wget "https://github.com/CosmWasm/wasmvm/releases/download/v1.5.2/libwasmvm.x86_64.so" -O "$HOME/.empe-chain/lib/libwasmvm.x86_64.so"
  echo "alias emped='LD_LIBRARY_PATH=/root/.empe-chain/lib:\$LD_LIBRARY_PATH /usr/local/bin/emped'" >> ~/.bashrc
  source ~/.bashrc

  # Systemd
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

  # Init node
  emped init "$MONIKER" --chain-id empe-testnet-2

  # Genesis & Addrbook
  wget -O $HOME/.empe-chain/config/genesis.json "https://raw.githubusercontent.com/empe-io/empe-chains/master/testnet-2/genesis.json"
  wget -O $HOME/.empe-chain/config/addrbook.json "https://raw.githubusercontent.com/MictoNode/empe-chain/main/addrbook.json"

  # Config
  sed -i.bak -e "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0.0001uempe\"/" $HOME/.empe-chain/config/app.toml
  sed -i -e "s/^pruning *=.*/pruning = \"custom\"/" $HOME/.empe-chain/config/app.toml
  sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"100\"/" $HOME/.empe-chain/config/app.toml
  sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"10\"/" $HOME/.empe-chain/config/app.toml
  sed -i "s/^indexer *=.*/indexer = \"null\"/" $HOME/.empe-chain/config/config.toml

  emped tendermint unsafe-reset-all --home $HOME/.empe-chain --keep-addr-book

  echo -e "\n🔄 Downloading latest snapshot..."
  SNAPSHOT_URL="https://server-5.itrocket.net/testnet/empeiria/"
  LATEST_SNAPSHOT=$(curl -s $SNAPSHOT_URL | grep -oP 'empeiria_\d{4}-\d{2}-\d{2}_\d+_snap\.tar\.lz4' | sort | tail -n 1)

  if [ -n "$LATEST_SNAPSHOT" ]; then
    curl "$SNAPSHOT_URL$LATEST_SNAPSHOT" | lz4 -dc - | tar -xf - -C $HOME/.empe-chain
  else
    echo "❌ Snapshot tidak ditemukan"
  fi

  echo -e "\n✅ Instalasi selesai! Jalankan node dengan:"
  echo -e "\e[1;34msudo systemctl start emped && sudo journalctl -fu emped -o cat\e[0m"

elif [ "$OPTION" == "2" ]; then
  echo -e "\n🆙 Memulai proses upgrade dari v0.3.0 ke v0.4.0..."

  cd $HOME
  mkdir -p $HOME/.empe-chain/cosmovisor/upgrades/v0.4.0/bin
  wget https://github.com/empe-io/empe-chain-releases/raw/master/v0.4.0/emped_v0.4.0_linux_amd64.tar.gz
  tar -xvf emped_v0.4.0_linux_amd64.tar.gz
  rm emped_v0.4.0_linux_amd64.tar.gz
  chmod +x emped
  mv emped $HOME/.empe-chain/cosmovisor/upgrades/v0.4.0/bin

  sudo ln -sfn $HOME/.empe-chain/cosmovisor/upgrades/v0.4.0 $HOME/.empe-chain/cosmovisor/current
  sudo ln -sfn $HOME/.empe-chain/cosmovisor/current/bin/emped /usr/local/bin/emped

  echo -e "\n✅ Upgrade selesai! Restart node dengan:\n"
  echo -e "\e[1;34msudo systemctl restart emped && sudo journalctl -fu emped -o cat\e[0m"

else
  echo -e "\n❌ Pilihan tidak valid. Jalankan ulang script dan pilih 1 atau 2."
fi
