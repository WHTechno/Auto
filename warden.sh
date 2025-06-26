#!/bin/bash

# Prompt input Moniker
read -p "Masukkan MONIKER node Anda: " MONIKER
echo "Moniker yang Anda masukkan: $MONIKER"

# Instal Go
cd $HOME
VER="1.23.1"
wget "https://golang.org/dl/go$VER.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go$VER.linux-amd64.tar.gz"
rm "go$VER.linux-amd64.tar.gz"
[ ! -f ~/.bash_profile ] && touch ~/.bash_profile
echo "export PATH=\$PATH:/usr/local/go/bin:~/go/bin" >> ~/.bash_profile
source ~/.bash_profile
[ ! -d ~/go/bin ] && mkdir -p ~/go/bin

# Set environment variables
echo "export WALLET=wallet" >> ~/.bash_profile
echo "export MONIKER=\"$MONIKER\"" >> ~/.bash_profile
echo "export WARDEN_CHAIN_ID=chiado_10010-1" >> ~/.bash_profile
echo "export WARDEN_PORT=18" >> ~/.bash_profile
source ~/.bash_profile

# Download wardend binary
cd $HOME
rm -rf bin
mkdir bin && cd bin
wget -O wardend https://github.com/warden-protocol/wardenprotocol/releases/download/v0.6.3/wardend-0.6.3-linux-amd64
chmod +x wardend
mv wardend ~/go/bin

# Init node
wardend init "$MONIKER"
sed -i -e "s|^node *=.*|node = \"tcp://localhost:${WARDEN_PORT}657\"|" $HOME/.warden/config/client.toml

# Download genesis and addrbook
wget -O $HOME/.warden/config/genesis.json https://server-2.itrocket.net/testnet/warden/genesis.json
wget -O $HOME/.warden/config/addrbook.json https://server-2.itrocket.net/testnet/warden/addrbook.json

# Set seeds and peers
SEEDS="8288657cb2ba075f600911685670517d18f54f3b@warden-testnet-seed.itrocket.net:18656"
PEERS="b14f35c07c1b2e58c4a1c1727c89a5933739eeea@warden-testnet-peer.itrocket.net:18656,de9e8c44039e240ff31cbf976a0d4d673d4e4734@188.165.213.192:26656,8a46610d69921c1031ea536cd5dca0a2979cf1b2@168.119.10.134:29479,73a865805db875019306049cf9bc83a05180ff80@57.128.193.18:20145,1963c16796b81c66782a9c858e5c7033fc6b5273@185.133.251.226:26656,c06eefafade8141218c7f59d467cbaccfb79b98c@65.21.10.115:27356,fa9955b398952c4a1b73f53ca649fd4e9cad9c81@65.108.74.113:11956,d4f3a395a6a2f1a15253f62cb01288305a466240@138.201.141.114:19656,8a2624792884eb8135ae7b11b739688388fa2e55@65.109.83.40:27356,150e202eb884424789a7e059ccdc7f07e764f977@88.198.59.234:27656,4eebb0b81c59639f9c82de3525de18fcfc55318e@5.9.116.21:27356,52cda545941f6bc85daf379a5661c8747c8272f3@15.204.143.180:18656,2d7ef2d2b1ad30d06a4a6d31943d301b5e99a3b9@15.235.50.120:20145,29dfeed0f7933111c5452a1af4ca67b2fe4346f5@198.27.80.53:26656,1b364274f2327ff55c1e5a11566b4e9789dcef82@94.130.143.122:30656,49fbeaf2bcfef6bd8c1c20c78489b7061c3351a3@37.27.19.58:18656,bee9e9daec3ca13b7961115790db642f84e1c277@37.27.97.16:26656,4c54d61784741680d7398367a47c42b6ff32ae7e@38.242.249.55:18656,4f721cf7df1ae8833f2c41437e25d8b188a2b3be@65.109.75.155:11956,4291fec222303269daf0cb564f5f321262e84bb4@46.4.169.227:27656,7e886df20e746a360ddc22e622ae9448089bde40@49.12.129.31:26656"
sed -i -e "/^\[p2p\]/,/^\[/{s/^[[:space:]]*seeds *=.*/seeds = \"$SEEDS\"/}" \
       -e "/^\[p2p\]/,/^\[/{s/^[[:space:]]*persistent_peers *=.*/persistent_peers = \"$PEERS\"/}" $HOME/.warden/config/config.toml

# Custom ports in app.toml
sed -i.bak -e "s%:1317%:${WARDEN_PORT}317%g;
s%:8080%:${WARDEN_PORT}080%g;
s%:9090%:${WARDEN_PORT}090%g;
s%:9091%:${WARDEN_PORT}091%g;
s%:8545%:${WARDEN_PORT}545%g;
s%:8546%:${WARDEN_PORT}546%g;
s%:6065%:${WARDEN_PORT}065%g" $HOME/.warden/config/app.toml

# Custom ports in config.toml
sed -i.bak -e "s%:26658%:${WARDEN_PORT}658%g;
s%:26657%:${WARDEN_PORT}657%g;
s%:6060%:${WARDEN_PORT}060%g;
s%:26656%:${WARDEN_PORT}656%g;
s%^external_address = \"\"%external_address = \"$(wget -qO- eth0.me):${WARDEN_PORT}656\"%;
s%:26660%:${WARDEN_PORT}660%g" $HOME/.warden/config/config.toml

# Pruning
sed -i -e "s/^pruning *=.*/pruning = \"custom\"/" $HOME/.warden/config/app.toml 
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"100\"/" $HOME/.warden/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"19\"/" $HOME/.warden/config/app.toml

# Gas price dan Prometheus
sed -i 's|minimum-gas-prices =.*|minimum-gas-prices = "25000000award"|g' $HOME/.warden/config/app.toml
sed -i -e "s/prometheus = false/prometheus = true/" $HOME/.warden/config/config.toml
sed -i -e "s/^indexer *=.*/indexer = \"null\"/" $HOME/.warden/config/config.toml

# Buat service
sudo tee /etc/systemd/system/wardend.service > /dev/null <<EOF
[Unit]
Description=Warden node
After=network-online.target
[Service]
User=$USER
WorkingDirectory=$HOME/.warden
ExecStart=$(which wardend) start --home $HOME/.warden
Restart=on-failure
RestartSec=5
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

# Reset dan snapshot
wardend tendermint unsafe-reset-all --home $HOME/.warden
if curl -s --head https://server-2.itrocket.net/testnet/warden/warden_2025-06-26_3644831_snap.tar.lz4 | head -n 1 | grep "200" > /dev/null; then
  curl https://server-2.itrocket.net/testnet/warden/warden_2025-06-26_3644831_snap.tar.lz4 | lz4 -dc - | tar -xf - -C $HOME/.warden
else
  echo "Snapshot tidak ditemukan."
fi

# Aktifkan service
sudo systemctl daemon-reload
sudo systemctl enable wardend
sudo systemctl restart wardend

echo -e "\n✅ Instalasi selesai. Gunakan perintah berikut untuk melihat log:\n  sudo journalctl -u wardend -f\n"
echo -e "⚠️  Simpan file *$HOME/.warden/config/priv_validator_key.json* di tempat yang aman untuk menghindari kehilangan akses validator!"
