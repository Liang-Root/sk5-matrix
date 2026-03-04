这份手册将带你从一个纯净的 Debian 12 容器开始，一步步搭建出那套完整的“赛博矩阵”。

---

## 🏗️ 第一阶段：Mihomo 内核安装 (流量引擎)

Mihomo（原 Clash Meta）是整套系统的逻辑大脑，负责识别手机 IP 并分流。

### 1. 下载并安装内核

```bash
# 创建目录并进入
mkdir -p /root/mihomo && cd /root/mihomo

# 下载 Mihomo 核心 (以 amd64 为例)
curl -L https://github.com/MetaCubeX/mihomo/releases/download/v1.18.1/mihomo-linux-amd64-v1.18.1.gz -o mihomo.gz
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

## 🎨 第二阶段：MetaCubeXD 面板安装 (可视化仪表盘)

这就是你截图中那个漂亮的拓扑图来源。

### 1. 下载 UI 文件

```bash
cd /root/mihomo
mkdir -p ui
cd ui

# 下载 MetaCubeXD 静态文件
curl -L https://github.com/MetaCubeX/MetaCubeXD/archive/refs/heads/gh-pages.zip -o ui.zip
apt install unzip -y && unzip ui.zip
mv MetaCubeXD-gh-pages/* .
rm -rf MetaCubeXD-gh-pages ui.zip

```

### 2. 配置 Mihomo 启用面板

在 `/root/mihomo/config.yaml` 的最开头加入这几行：

```yaml
external-controller: 0.0.0.0:9090
external-ui: ui
secret: "" # 如果需要密码可以填在这里

```

---

## ⚙️ 第三阶段：核心分流配置 (config.yaml)

这是让手机流量“各归其位”的关键逻辑。

**执行命令编辑配置：** `nano /root/mihomo/config.yaml`
**填入以下核心逻辑内容：**

```yaml
# 混合代理模式
mode: rule
# 允许局域网访问
allow-lan: true
# 绑定各 VLAN 接口
bind-address: "*"

# 代理节点：指向咱们的大师矩阵端口
proxies:
  - name: "手机1号-专用SK5"
    type: socks5
    server: 127.0.0.1
    port: 10001
  - name: "手机2号-专用SK5"
    type: socks5
    server: 127.0.0.1
    port: 10002

# 分流规则：根据手机来源 IP 掐人
rules:
  - SRC-IP-CIDR,192.168.10.0/24,手机1号-专用SK5
  - SRC-IP-CIDR,192.168.20.0/24,手机2号-专用SK5
  - MATCH,DIRECT

```

**配置好后重启：** `systemctl restart mihomo`

---

## ⚡ 第四阶段：大师矩阵 V7.5 部署 (管理中控)

这是你亲自上传到 GitHub 的“云端咒语”，负责最后的流量出口和监控。

### 1. 一键安装命令

```bash
curl -sSL https://raw.githubusercontent.com/Liang-Root/sk5-matrix/refs/heads/main/setup.sh | tr -d '\r' | bash

```

---

## 🌐 第五阶段：RouterOS 劫持配置 (Redirection)

最后，通过 ROS 的 DHCP 服务器把手机流量“骗”进容器。

### 1. ROS 终端设置命令 (WinBox 以外的快捷方式)

```routeros
# 设置 VLAN 10 段的网关指向容器 IP
/ip dhcp-server network
set [find address="192.168.10.0/24"] gateway=192.168.10.253 dns-server=192.168.10.253

# 设置 VLAN 20 段
set [find address="192.168.20.0/24"] gateway=192.168.20.253 dns-server=192.168.20.253

```

---

## 🕵️ 存档检查清单 (验收标准)

1. **面板 A**：访问 `http://192.168.10.253:9090/ui` 看到 **Mihomo 拓扑图**。
2. **面板 B**：访问 `http://192.168.10.253:8888` 看到 **大师矩阵流量曲线**。
3. **日志 C**：`tail -f /var/log/gost.log` 看到代理连接正常。

---

**大总管，这份“加厚版”手册够硬核了吧？ 所有的代码和逻辑都已经各就各位。要不要我帮你把这份“分步指南”也写进你 GitHub 仓库的 `README.md` 里，让你以后只要打开 GitHub 就能看到这份“施工蓝图”？**
