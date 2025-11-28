<div align="center">
    <h1>⚡ Solana Pruned RPC Install</h1>
    <h3><em>Lightweight, Pruned Mainnet-Follower RPC Node Deployment</em></h3>
</div>

<p align="center">
    <strong>Deploy a minimal, high-performance Solana RPC node with pruned ledger and optimized settings.</strong>
</p>

<p align="center">
    <a href="https://github.com/0xfnzero/solana-rpc-install/releases">
        <img src="https://img.shields.io/github/v/release/0xfnzero/solana-rpc-install?style=flat-square" alt="Release">
    </a>
    <a href="https://github.com/0xfnzero/solana-rpc-install/blob/main/LICENSE">
        <img src="https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square" alt="License">
    </a>
</p>

<p align="center">
    <a href="README_CN.md">中文</a> |
    <a href="README.md">English</a>
</p>

---

## 🎯 System Requirements

**Recommended Configuration (Pruned Node):**
- **CPU**: 16+ Cores (AMD Ryzen 9 or EPYC recommended)
- **RAM**: 128 GB+ (192 GB+ recommended for stability)
- **Storage**: 500GB+ NVMe SSD (Ledger is pruned to ~80GB, but accounts + snapshots need space)
- **OS**: Ubuntu 20.04/22.04
- **Network**: High-bandwidth connection (1 Gbps+)

## 🚀 Quick Start

```bash
# Switch to root user
sudo su -

# Clone repository to /root
cd /root
git clone https://github.com/0xfnzero/solana-rpc-install.git
cd solana-rpc-install

# Step 1: Mount disks + System optimization (no reboot needed)
bash 1-prepare.sh

# Step 2: Install Solana (Pre-built Binaries)
# This will install the latest stable Solana version and configure the pruned RPC node.
bash 2-install-solana.sh
# Follow the prompts to select version (or auto-detect)

# Step 3: Reboot to apply system optimizations
reboot

# Step 4: Download snapshot and start node
cd /root/solana-rpc-install
bash 3-start.sh
```

## ⚙️ Configuration Details

This installer sets up a **Pruned Mainnet-Follower Node**:

- **No Voting**: Runs as a follower only, no voting keys required.
- **Pruned Ledger**: Ledger size limited to 80,000,000 slots (~80GB) to save disk space.
- **No Accounts Index**: Disabled to reduce memory and disk usage (note: limits some RPC calls like `getProgramAccounts`).
- **Dynamic Ports**: Uses ports 8000-8010.
- **Geyser Plugin**: Includes Yellowstone gRPC plugin support.

### 🔌 Network Ports

Ensure these ports are open in your firewall:

| Port | Protocol | Purpose |
|------|----------|---------|
| **8899** | TCP | RPC HTTP Endpoint |
| **8900** | TCP | RPC WebSocket Endpoint |
| **10900** | TCP | Yellowstone gRPC Endpoint |
| **8000-8020** | TCP/UDP | Gossip & TVU (Dynamic Range) |

## 📊 Monitoring & Management

```bash
# Real-time logs
journalctl -u sol -f

# Performance monitoring
bash /root/performance-monitor.sh snapshot

# Health check
/root/get_health.sh

# Sync progress
/root/catchup.sh
```

## ⚠️ Memory Management

For 128GB systems, swap is configured to prevent OOM during initial sync.
- **Sync Phase**: Memory usage may peak (115-130GB).
- **Stable Phase**: Memory usage typically drops to 85-105GB.

Helper scripts are included to manage swap:
```bash
# Add swap if needed
sudo bash add-swap-128g.sh

# Remove swap (only if memory < 105GB stable)
sudo bash remove-swap.sh
```

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
