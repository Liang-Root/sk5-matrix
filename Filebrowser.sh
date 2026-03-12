#!/bin/bash
set -e

echo "========================================================"
echo "      🚀 正在安装 Filebrowser (Mihomo 专属管理版) 🚀      "
echo "========================================================"

# 1. 下载并安装官方最新版核心
curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash

# 2. 确保目录存在
mkdir -p /root/mihomo

# 3. 初始化数据库和配置 (如果以前有残留则先清理)
rm -f /root/mihomo/filebrowser.db
/usr/local/bin/filebrowser config init -d /root/mihomo/filebrowser.db -a 0.0.0.0 -p 9999 -r /root/mihomo

# 4. 创建默认管理员账号 (账号: admin, 密码: admin)
/usr/local/bin/filebrowser users add admin admin -d /root/mihomo/filebrowser.db

# 5. 注册为底层守护进程
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

# 6. 启动服务并设置开机自启
systemctl daemon-reload
systemctl enable filebrowser
systemctl restart filebrowser

echo "--------------------------------------------------------"
echo "✔️ 安装成功！"
echo "🌐 访问地址: http://你的CT管理IP:9999"
echo "🔑 初始账号: admin"
echo "🔑 初始密码: admin"
echo "📁 根目录已永久锁定为: /root/mihomo"
echo "--------------------------------------------------------"