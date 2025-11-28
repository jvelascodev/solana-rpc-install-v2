#!/bin/bash
set -euo pipefail

# ============================================
# 步骤2: 安装 Solana (使用官方预编译二进制)
# ============================================
# 前置条件: 必须先运行 1-prepare.sh
# - Install dependencies
# - Download & Install Solana Binaries
# - Create validator keypair
# - UFW enable + allow ports
# - Create validator-rpc.sh and systemd service
# - Download Yellowstone gRPC geyser & copy optimized config
# - Copy helper scripts from project directory
# ============================================

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BASE=${BASE:-/root/sol}
LEDGER="$BASE/ledger"
ACCOUNTS="$BASE/accounts"
SNAPSHOT="$BASE/snapshot"
BIN="$BASE/bin"
TOOLS="$BASE/tools"
KEYPAIR="$BIN/validator-keypair.json"
LOGFILE=/root/solana-rpc.log
GEYSER_CFG="$BIN/yellowstone-config.json"
SERVICE_NAME=${SERVICE_NAME:-sol}
SOLANA_INSTALL_DIR="/usr/local/solana"

# Yellowstone artifacts (as vars)
YELLOWSTONE_TARBALL_URL="https://github.com/rpcpool/yellowstone-grpc/releases/download/v10.0.1%2Bsolana.3.0.6/yellowstone-grpc-geyser-release24-x86_64-unknown-linux-gnu.tar.bz2"

if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] 请用 root 执行：sudo bash $0" >&2
  exit 1
fi

echo "==> 节点安装（预编译二进制）开始..."

# =============================
# Step 0: Verify Solana version first
# =============================
echo "==> 0) 选择 Solana 版本 ..."

# Interactive version selection
while true; do
  read -p "请输入 Solana 版本号 (例如 v1.18.15, v1.17.31) [按回车自动检测最新稳定版]: " SOLANA_VERSION
  
  if [[ -z "$SOLANA_VERSION" ]]; then
     echo "   - 正在检测最新稳定版..."
     SOLANA_VERSION=$(curl -s https://api.github.com/repos/solana-labs/solana/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
     if [[ -z "$SOLANA_VERSION" ]]; then
         echo "[错误] 无法自动检测版本，请手动输入。"
         continue
     fi
     echo "   - 检测到最新版本: $SOLANA_VERSION"
  fi

  # Validate version format
  if [[ ! "$SOLANA_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "[错误] 版本号格式不正确，应为 vX.Y.Z 格式 (例如 v1.18.15)"
    continue
  fi

  SOLANA_DOWNLOAD_URL="https://github.com/solana-labs/solana/releases/download/${SOLANA_VERSION}/solana-release-x86_64-unknown-linux-gnu.tar.bz2"
  
  echo "正在验证版本 ${SOLANA_VERSION} 下载链接..."
  if wget --spider "$SOLANA_DOWNLOAD_URL" 2>/dev/null; then
    echo "版本 ${SOLANA_VERSION} 验证成功，继续安装流程..."
    break
  else
    echo "[错误] 版本 ${SOLANA_VERSION} 下载链接无效: $SOLANA_DOWNLOAD_URL"
    read -p "是否重新输入版本号？(y/n): " retry
    [[ "$retry" != "y" && "$retry" != "Y" ]] && exit 1
  fi
done

echo "==> 版本验证完成，开始系统配置..."
apt update -y
apt install -y wget curl bzip2 ufw libssl-dev pkg-config zlib1g-dev libclang-dev git python3-venv || true

echo "==> 1) 安装/更新 Solana 二进制文件 ..."
cd /tmp
echo "   - 下载 Solana ${SOLANA_VERSION} ..."
wget -q --show-progress -O solana-release.tar.bz2 "$SOLANA_DOWNLOAD_URL"

echo "   - 解压安装 ..."
tar -xjvf solana-release.tar.bz2
rm -rf "$SOLANA_INSTALL_DIR"
mv solana-release "$SOLANA_INSTALL_DIR"
rm solana-release.tar.bz2

# Configure PATH persistently
export PATH="$SOLANA_INSTALL_DIR/bin:$PATH"

# Add to bashrc if not already present
if ! grep -q 'solana/bin' /root/.bashrc 2>/dev/null; then
  echo "export PATH=\"$SOLANA_INSTALL_DIR/bin:\$PATH\"" >> /root/.bashrc
fi

# Add to system-wide profile
echo "export PATH=\"$SOLANA_INSTALL_DIR/bin:\$PATH\"" > /etc/profile.d/solana.sh
fi

echo "   - Solana ${SOLANA_VERSION} 安装成功"
solana --version

echo "==> 2) 生成 Validator Keypair (仅用于身份标识，不参与投票) ..."
[[ -f "$KEYPAIR" ]] || solana-keygen new -o "$KEYPAIR" --no-bip39-passphrase

echo "==> 3) 配置 UFW 防火墙 ..."
ufw --force enable
ufw allow 22/tcp
# RPC & Gossip Ports
ufw allow 8000:8020/tcp
ufw allow 8000:8020/udp
ufw allow 8899/tcp   # RPC HTTP
ufw allow 8900/tcp   # RPC WS
ufw allow 10900/tcp  # GRPC
ufw status | head -n 10 || true


echo "==> 4) 复制 validator 启动脚本到 $BIN ..."
# Copy the new RPC specific script
cp -f "$SCRIPT_DIR/validator-rpc.sh" "$BIN/validator-rpc.sh"
chmod +x "$BIN/validator-rpc.sh"

echo "==> 5) 复制 systemd 服务配置..."
# We assume sol.service is already updated to point to validator-rpc.sh or we update it here
cp -f "$SCRIPT_DIR/sol.service" /etc/systemd/system/${SERVICE_NAME}.service
# Update ExecStart in the service file just in case it's not correct in the source
sed -i "s|ExecStart=.*|ExecStart=$BIN/validator-rpc.sh|g" /etc/systemd/system/${SERVICE_NAME}.service

systemctl daemon-reload
echo "   ✓ systemd 服务配置已更新"

echo "==> 6) 下载 Yellowstone gRPC geyser 与配置 ..."
cd "$BIN"
if [[ ! -f "yellowstone-grpc-geyser.so" ]]; then
    echo "   - 下载 Yellowstone Geyser ..."
    wget -q "$YELLOWSTONE_TARBALL_URL" -O yellowstone-grpc-geyser.tar.bz2
    tar -xvjf yellowstone-grpc-geyser.tar.bz2
    # Move the .so file to bin if it's in a subdir (depends on tarball structure, usually it's flat or in a dir)
    find . -name "libyellowstone_grpc_geyser.so" -exec cp {} . \;
    # Rename if needed to match config expectation (usually config points to .so)
    # The config usually expects the full path.
fi

echo "   - 复制优化后的 yellowstone-config.json ..."
cp -f "$SCRIPT_DIR/yellowstone-config.json" "$GEYSER_CFG"
echo "   ✓ 已应用 Geyser 配置"

echo "==> 7) 复制辅助脚本到 /root ..."
cp -f "$SCRIPT_DIR/redo_node.sh"         /root/redo_node.sh
cp -f "$SCRIPT_DIR/restart_node.sh"      /root/restart_node.sh
cp -f "$SCRIPT_DIR/get_health.sh"        /root/get_health.sh
cp -f "$SCRIPT_DIR/catchup.sh"           /root/catchup.sh
cp -f "$SCRIPT_DIR/performance-monitor.sh" /root/performance-monitor.sh
cp -f "$SCRIPT_DIR/add-swap-128g.sh"     /root/add-swap-128g.sh
cp -f "$SCRIPT_DIR/remove-swap.sh"       /root/remove-swap.sh
chmod +x /root/redo_node.sh /root/restart_node.sh /root/get_health.sh /root/catchup.sh /root/performance-monitor.sh /root/add-swap-128g.sh /root/remove-swap.sh

echo "==> 8) 配置开机自启 ..."
systemctl enable "${SERVICE_NAME}"

echo ""
echo "============================================"
echo "✅ 步骤 2 完成: Solana RPC 节点安装完成!"
echo "============================================"
echo ""
echo "版本: ${SOLANA_VERSION}"
echo "安装路径: ${SOLANA_INSTALL_DIR}"
echo ""
echo ""
echo "============================================"
echo "✅ 步骤 2 完成: Solana 安装完成!"
echo "============================================"
echo ""
echo "版本: ${SOLANA_VERSION}"
echo "安装路径: ${SOLANA_INSTALL_DIR}"
echo ""
echo "📋 下一步:"
echo ""
echo "步骤 3: 重启系统（使系统优化生效）"
echo "  reboot"
echo ""
echo "步骤 4: 重启后回到项目目录，下载快照并启动节点"
echo "  cd $SCRIPT_DIR"
echo "  bash 3-start.sh"
echo ""
