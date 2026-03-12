
---

```markdown
# 🚀 六脉神剑 V9.0 赛博矩阵 | 终极防漏网架构部署指南

这份手册将带你从一个纯净的 Debian 12 容器开始，一步步搭建出这套“宁可断网，绝不漏网”的短视频工作室底层矩阵。

---

## 🏗️ 第一阶段：Mihomo 内核安装 (底层流量劫持)

Mihomo（原 Clash Meta）是整套系统的底层大脑，负责开启 TUN 网关、强制劫持手机 IP 并分流。

### 1. 下载并安装内核

```bash
# 创建目录并进入
mkdir -p /root/mihomo && cd /root/mihomo

# 下载 Mihomo 核心 (以 amd64 为例)
curl -L [https://github.com/MetaCubeX/mihomo/releases/download/v1.18.1/mihomo-linux-amd64-v1.18.1.gz](https://github.com/MetaCubeX/mihomo/releases/download/v1.18.1/mihomo-linux-amd64-v1.18.1.gz) -o mihomo.gz
gunzip mihomo.gz
chmod +x mihomo
mv mihomo /usr/local/bin/mihomo

```

### 2. 编写系统服务 (让它后台自启)

执行以下命令创建服务文件：

```bash
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

systemctl daemon-reload
systemctl enable mihomo

```

---

## 🎨 第二阶段：MetaCubeXD 面板安装 (连接监控大屏)

这就是咱们用来抓取“漏网之鱼”和查看连接拓扑的可视化仪表盘。

### 1. 下载 UI 文件

```bash
cd /root/mihomo
mkdir -p ui
cd ui

# 下载 MetaCubeXD 静态文件
curl -L [https://github.com/MetaCubeX/MetaCubeXD/archive/refs/heads/gh-pages.zip](https://github.com/MetaCubeX/MetaCubeXD/archive/refs/heads/gh-pages.zip) -o ui.zip
apt install unzip -y && unzip ui.zip
mv MetaCubeXD-gh-pages/* .
rm -rf MetaCubeXD-gh-pages ui.zip

```

---

## ⚙️ 第三阶段：云端拉取核心分流配置 (config.yaml)

告别手动编辑，直接一键拉取咱们打磨好的“终极防漏网生死锁”配置（内置 UDP 443 阻断与 Fake-IP 防治套娃）：

```bash
curl -sSL [https://raw.githubusercontent.com/Liang-Root/sk5-matrix/refs/heads/main/config.yaml](https://raw.githubusercontent.com/Liang-Root/sk5-matrix/refs/heads/main/config.yaml) -o /root/mihomo/config.yaml
systemctl restart mihomo

```

---

## ⚡ 第四阶段：六脉神剑 V9.0 部署 (SDN 策略路由控制台)

这是整套矩阵的灵魂面板，负责底层 VLAN 网卡生成、策略路由（IP Rule）锁定以及智能流量统计。

**一键安装/更新命令：**

```bash
curl -sSL [https://github.com/Liang-Root/sk5-matrix/raw/refs/heads/main/setup.sh](https://github.com/Liang-Root/sk5-matrix/raw/refs/heads/main/setup.sh) | tr -d '\r' | bash

```

---

## 📂 第五阶段：Filebrowser 专属配置修改器 (告别 SSH)

为了方便随时在网页上修改 `config.yaml` 和查看日志，无需使用 ssh 工具。

**一键部署可视化修改器：**

```bash
curl -sSL [https://raw.githubusercontent.com/Liang-Root/sk5-matrix/refs/heads/main/Filebrowser.sh](https://raw.githubusercontent.com/Liang-Root/sk5-matrix/refs/heads/main/Filebrowser.sh) | tr -d '\r' | bash

```

---

## 🌐 第六阶段：RouterOS 劫持配置 (Redirection)

最后，通过 ROS 的 DHCP 服务器把手机的网关强行指向咱们的 Debian 容器（请根据实际 VLAN IP 修改）。

### 1. ROS 终端设置命令

```routeros
# 设置 VLAN 10 段的网关指向容器 IP
/ip dhcp-server network
set [find address="192.168.10.0/24"] gateway=192.168.10.253 dns-server=192.168.10.253

# 设置 VLAN 20 段
set [find address="192.168.20.0/24"] gateway=192.168.20.253 dns-server=192.168.20.253

```

---

## 🕵️ 三位一体指挥中心 (验收标准)

部署完成后，你将拥有三个强大的可视化面板（假设你的容器管理 IP 为 `192.168.200.253`）：

1. 🎛️ **六脉神剑控制台 (端口 8888)**：`http://192.168.200.253:8888`
* *功能：一键生成/销毁 VLAN 节点，实时查看智能流量（KB/MB/GB）与连通性。*


2. 👁️ **Mihomo 连接大屏 (端口 9090)**：`http://192.168.200.253:9090/ui`
* *功能：监控手机实时连接，核查底层防封策略（UDP 等）是否生效。*


3. 📝 **Filebrowser 规则修改器 (端口 9999)**：`http://192.168.200.253:9999`
* *功能：网页端直接修改 `config.yaml`，告别 Linux 命令行。（默认账号密码：admin）*



**享受宁可断网、绝不漏网的极致安全感吧！🚀**

```

