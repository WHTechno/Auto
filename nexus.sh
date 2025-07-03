#!/bin/bash

set -e

# Menampilkan logo
bash logo/logowh.sh

# ========== 1. INSTALL DEPENDENSI DASAR ==========
echo "[⏳] Menginstall dependensi dasar..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y screen curl build-essential pkg-config libssl-dev git-all protobuf-compiler wget tar gawk bison gcc make bc

# ========== 2. INSTALL RUST ==========
if ! command -v cargo &> /dev/null; then
  echo "[⏳] Menginstall Rust..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source "$HOME/.cargo/env"
else
  echo "[✔] Rust sudah terinstall."
fi

# Tambahkan target riscv (optional)
rustup target add riscv32i-unknown-none-elf || true

# ========== 3. CEK VERSI LDD DAN INSTALL glibc JIKA PERLU ==========
LDD_VERSION=$(ldd --version 2>&1 | head -n1 | grep -oP '\d+\.\d+' | head -n1)
echo "[ℹ️] Versi ldd terdeteksi: $LDD_VERSION"

NEED_GLIBC=false
LDD_VERSION_MAJOR=$(echo "$LDD_VERSION" | cut -d. -f1)
LDD_VERSION_MINOR=$(echo "$LDD_VERSION" | cut -d. -f2)

if [ "$LDD_VERSION_MAJOR" -lt 2 ]; then
  NEED_GLIBC=true
elif [ "$LDD_VERSION_MAJOR" -eq 2 ] && [ "$LDD_VERSION_MINOR" -lt 39 ]; then
  NEED_GLIBC=true
fi

if [ "$NEED_GLIBC" = true ]; then
  echo "[!] Versi ldd terlalu rendah. Akan install glibc 2.39."
  echo "[⏳] Menginstall glibc 2.39..."
  wget -c https://ftp.gnu.org/gnu/glibc/glibc-2.39.tar.gz
  tar -zxvf glibc-2.39.tar.gz
  cd glibc-2.39
  mkdir glibc-build && cd glibc-build
  ../configure --prefix=/opt/glibc-2.39
  make -j$(nproc)
  sudo make install
  cd ~
  echo "[✔] glibc 2.39 telah diinstal di /opt/glibc-2.39"
else
  echo "[✔] Versi ldd >= 2.39. Tidak perlu install glibc."
fi

# ========== 4. INSTALL NEXUS CLI ==========
if [ ! -f "$HOME/.nexus/bin/nexus-network" ]; then
  echo "[⏳] Menginstall Nexus CLI..."
  curl https://cli.nexus.xyz/ | sh
  source ~/.bashrc
else
  echo "[✔] Nexus CLI sudah terinstall."
fi

# ========== 5. INPUT ==========
read -p "Masukkan wallet address Anda: " WALLET_ADDRESS
read -p "Masukkan node ID Anda: " NODE_ID

# ========== 6. JALANKAN DALAM SCREEN ==========
echo "[🚀] Menjalankan Nexus Node di screen bernama 'nexus'..."

if [ "$NEED_GLIBC" = true ]; then
  LIBCMD="/opt/glibc-2.39/lib/ld-linux-x86-64.so.2 --library-path /opt/glibc-2.39/lib:/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu"
  screen -dmS nexus bash -c "
    $LIBCMD \$HOME/.nexus/bin/nexus-network register-user --wallet-address $WALLET_ADDRESS;
    sleep 5;
    $LIBCMD \$HOME/.nexus/bin/nexus-network start --node-id $NODE_ID;
  "
else
  screen -dmS nexus bash -c "
    nexus-network register-user --wallet-address $WALLET_ADDRESS;
    sleep 5;
    nexus-network start --node-id $NODE_ID;
  "
fi

echo ""
echo "[✔] Nexus node sedang berjalan di screen 'nexus'."
echo "📟 Untuk membuka kembali screen: screen -r nexus"
echo "📤 Untuk detach dari screen: tekan Ctrl+A lalu D"
