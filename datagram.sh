#!/bin/bash

# Prompt API key dari user
read -p "Masukkan API Key kamu: " API_KEY

# Hapus file dan direktori lama jika ada
[ -f /usr/local/bin/datagram-cli ] && sudo rm -f /usr/local/bin/datagram-cli
[ -f datagram.log ] && rm -f datagram.log
[ -d ~/.datagram ] && rm -rf ~/.datagram

# Unduh dan pasang binary terbaru
wget -q https://github.com/Datagram-Group/datagram-cli-release/releases/latest/download/datagram-cli-x86_64-linux
sudo mv datagram-cli-x86_64-linux /usr/local/bin/datagram-cli
sudo chmod +x /usr/local/bin/datagram-cli

# Jalankan dengan nohup di background
nohup datagram-cli run -- -key "$API_KEY" > datagram.log 2>&1 &

# Tampilkan log real-time
echo "✅ Datagram sedang berjalan. Menampilkan log di bawah:"
sleep 2
tail -f datagram.log
