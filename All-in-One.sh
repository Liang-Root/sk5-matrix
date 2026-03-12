#!/bin/bash
set -e

echo "=================================================================="
echo " 🚀 正在执行 六脉神剑 V9.0 (All-in-One) 究极全自动部署脚本 🚀 "
echo "=================================================================="

# ==========================================
# 步骤 1：安装基础依赖
# ==========================================
echo -e "\n[1/6] 📦 正在更新系统并安装依赖环境..."
apt update -y
apt install -y curl wget unzip python3 python3-pip python3-psutil iproute2 gunicorn logrotate
pip3 install flask gunicorn --break-system-packages --quiet

# ==========================================
# 步骤 2：部署 Gost 核心 (代理引擎)
# ==========================================
echo -e "\n[2/6] ⚙️ 正在下载 Gost 代理引擎..."
if [ ! -f /usr/local/bin/gost ]; then
    curl -L https://github.com/go-gost/gost/releases/download/v2.11.5/gost-linux-amd64-2.11.5.gz | gunzip > /usr/local/bin/gost
    chmod +x /usr/local/bin/gost
fi

# ==========================================
# 步骤 3：部署 Mihomo 内核与 UI (劫持大脑)
# ==========================================
echo -e "\n[3/6] 🧠 正在部署 Mihomo 内核与可视化大屏..."
mkdir -p /root/mihomo/ui && cd /root/mihomo
if [ ! -f /usr/local/bin/mihomo ]; then
    curl -L https://github.com/MetaCubeX/mihomo/releases/download/v1.18.1/mihomo-linux-amd64-v1.18.1.gz | gunzip > /usr/local/bin/mihomo
    chmod +x /usr/local/bin/mihomo
fi

# 下载 MetaCubeXD UI
cd /root/mihomo/ui
curl -L https://github.com/MetaCubeX/MetaCubeXD/archive/refs/heads/gh-pages.zip -o ui.zip
unzip -o ui.zip > /dev/null
mv MetaCubeXD-gh-pages/* . 2>/dev/null || true
rm -rf MetaCubeXD-gh-pages ui.zip

# 写入终极防漏网 config.yaml
cat <<'EOF' > /root/mihomo/config.yaml
allow-lan: true
mode: rule
log-level: info
external-controller: 0.0.0.0:9090
external-ui: ui

tun:
  enable: true
  stack: system
  auto-route: true
  auto-redirect: true
  auto-detect-interface: true

dns:
  enable: true
  listen: 0.0.0.0:1053
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  nameserver:
    - 223.5.5.5
    - 114.114.114.114

proxies:
  - name: "手机1号-专用SK5"
    type: socks5
    server: 127.0.0.1
    port: 10001
    udp: true
  - name: "手机2号-专用SK5"
    type: socks5
    server: 127.0.0.1
    port: 10002
    udp: true
  - name: "手机3号-专用SK5"
    type: socks5
    server: 127.0.0.1
    port: 10003
    udp: true
  - name: "手机4号-专用SK5"
    type: socks5
    server: 127.0.0.1
    port: 10004
    udp: true
  - name: "手机5号-专用SK5"
    type: socks5
    server: 127.0.0.1
    port: 10005
    udp: true
  - name: "手机6号-专用SK5"
    type: socks5
    server: 127.0.0.1
    port: 10006
    udp: true

proxy-groups:
  - name: "默认代理"
    type: select
    proxies:
      - "手机1号-专用SK5"
      - "手机2号-专用SK5"
      - "手机3号-专用SK5"
      - "手机4号-专用SK5"
      - "手机5号-专用SK5"
      - "手机6号-专用SK5"
      - DIRECT

rules:
  # 0. 核心防循环生死锁：给 Gost 开通 VIP 通道，绝对禁止代理套娃
  - PROCESS-NAME,gost,DIRECT

  # 1. 绝杀锁：物理斩断 UDP 443 (QUIC) 偷跑协议
  - AND,((NETWORK,UDP),(DST-PORT,443)),REJECT

  # 2. 局域网白名单：确保基础内网通信正常
  - DST-IP-CIDR,192.168.0.0/16,DIRECT
  - DST-IP-CIDR,198.18.0.0/15,DIRECT

  # 3. 矩阵核心分流逻辑：认准手机的内网 IP，强制走对应节点
  - SRC-IP-CIDR,192.168.10.0/24,手机1号-专用SK5
  - SRC-IP-CIDR,192.168.20.0/24,手机2号-专用SK5
  - SRC-IP-CIDR,192.168.30.0/24,手机3号-专用SK5
  - SRC-IP-CIDR,192.168.40.0/24,手机4号-专用SK5
  - SRC-IP-CIDR,192.168.50.0/24,手机5号-专用SK5
  - SRC-IP-CIDR,192.168.60.0/24,手机6号-专用SK5

  # 4. 恢复兜底直连：让 Web 面板、Gost 自身外发、本地回环等无害流量顺畅通行
  - MATCH,DIRECT
EOF

# ==========================================
# 步骤 4：部署 六脉神剑 V9.0 (SDN 策略路由中心)
# ==========================================
echo -e "\n[4/6] 🕸️ 正在生成 六脉神剑 V9.0 面板与底层路由控制器..."

[ ! -f /root/proxy_config.json ] && echo "[]" > /root/proxy_config.json
[ ! -f /root/proxy_ports.json ] && echo "[]" > /root/proxy_ports.json
[ ! -f /root/proxy_modes.json ] && echo "[]" > /root/proxy_modes.json
[ ! -f /root/proxy_binds.json ] && echo "[]" > /root/proxy_binds.json
[ ! -f /root/proxy_vlans.json ] && echo "[]" > /root/proxy_vlans.json
chmod 666 /root/*.json

curl -sSL https://raw.githubusercontent.com/Liang-Root/sk5-matrix/refs/heads/main/setup.sh | tr -d '\r' > /tmp/setup_v9.sh
# 提取 setup.sh 里的 python 写入部分 (防止重复跑全脚本)
sed -n '/cat <<.EOF. > \/root\/proxy_manager.py/,/EOF/p' /tmp/setup_v9.sh | bash

# ==========================================
# 步骤 5：部署 Filebrowser (配置修改器)
# ==========================================
echo -e "\n[5/6] 📁 正在部署 Filebrowser 专属编辑器..."
curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash > /dev/null
rm -f /root/mihomo/filebrowser.db
/usr/local/bin/filebrowser config init -d /root/mihomo/filebrowser.db -a 0.0.0.0 -p 9999 -r /root/mihomo > /dev/null
/usr/local/bin/filebrowser users add admin admin -d /root/mihomo/filebrowser.db > /dev/null

# ==========================================
# 步骤 6：注册所有系统服务并启动
# ==========================================
echo -e "\n[6/6] ⚡ 正在注册底层系统服务..."

# Mihomo 服务
cat <<EOF > /etc/systemd/system/mihomo.service
[Unit]
Description=Mihomo Logic Engine
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/mihomo -d /root/mihomo
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# 六脉神剑面板服务
cat <<EOF > /etc/systemd/system/proxy-web.service
[Unit]
Description=Cyber Proxy Matrix V9.0 Master SDN
After=network.target

[Service]
WorkingDirectory=/root
ExecStart=/usr/bin/gunicorn --workers 1 --worker-class gthread --threads 4 --bind 0.0.0.0:8888 --timeout 30 proxy_manager:app
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# Filebrowser 服务
cat <<EOF > /etc/systemd/system/filebrowser.service
[Unit]
Description=File Browser for Mihomo Config
After=network.target

[Service]
ExecStart=/usr/local/bin/filebrowser -d /root/mihomo/filebrowser.db
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable mihomo proxy-web filebrowser
systemctl restart mihomo proxy-web filebrowser

IP=$(ip route get 1.1.1.1 | grep -oP 'src \K\S+')

echo "=================================================================="
echo " 🎉 六脉神剑 V9.0 All-in-One 矩阵部署完毕！"
echo "=================================================================="
echo "🎛️  矩阵控制台 (VLAN/路由/节点): http://${IP}:8888"
echo "👁️  Mihomo 连接监控大屏: http://${IP}:9090/ui"
echo "📝  Filebrowser 规则修改器: http://${IP}:9999 (账号:admin 密码:admin)"
echo "------------------------------------------------------------------"