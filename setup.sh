#!/bin/bash
set -e

echo "💎 正在启动 V7.5 大师版矩阵部署程序..."

# 1. 环境加固：安装生产级组件
apt update && apt install python3 python3-pip python3-psutil curl iproute2 gunicorn logrotate -y
pip3 install flask gunicorn --break-system-packages || echo "✅ 环境组件已就绪"

# 2. 权限预设：防止日志写入失败
touch /var/log/proxy_panel.log /var/log/gost.log
chmod 666 /var/log/proxy_panel.log /var/log/gost.log

# 3. 部署核心代码：整合动态扩编、并发锁、Popen
cat <<'EOF' > /root/proxy_manager.py
from flask import Flask, request, render_template_string, jsonify
import subprocess, os, json, time, re, logging, threading

# 配置专业日志格式
logging.basicConfig(
    filename='/var/log/proxy_panel.log', 
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s'
)

app = Flask(__name__)
CONFIG_FILE, PORTS_FILE = '/root/proxy_config.json', '/root/proxy_ports.json'
io_lock = threading.Lock() # 解决并发竞态
last_io = {}
last_ms_time = {}

HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <title>五脉神剑 V7.5 | 大师矩阵</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        body { background: #020617; color: #38bdf8; font-family: 'Segoe UI', system-ui, sans-serif; }
        .card { background: rgba(15, 23, 42, 0.95); border: 1px solid #0ea5e9; border-radius: 12px; margin-bottom: 20px; transition: 0.3s; }
        .card:hover { border-color: #38bdf8; box-shadow: 0 0 15px rgba(14, 165, 233, 0.3); }
        .port-label { font-family: monospace; font-size: 1.1rem; font-weight: bold; color: #fff; }
        .form-control { background: #000; border: 1px solid #334155; color: #0ea5e9; font-size: 0.8rem; }
        .latency-tag { background: #1e293b; color: #facc15; font-size: 0.75rem; padding: 2px 8px; border-radius: 4px; border: 1px solid #eab308; }
    </style>
</head>
<body class="p-4">
    <div class="container">
        <div class="d-flex justify-content-between align-items-center mb-4">
            <h2 class="fw-bold text-white mb-0" style="letter-spacing:2px;">PROXY MATRIX <span class="text-info">V7.5</span></h2>
            <button type="button" class="btn btn-outline-info px-4 fw-bold" onclick="addNode()">+ 增加新节点</button>
        </div>
        <form method="post" id="mainForm">
            <div class="row g-3">
                {% for i in range(n) %}
                <div class="col-md-6 col-lg-4">
                    <div class="card p-3 shadow-sm">
                        <div class="d-flex justify-content-between align-items-center mb-2">
                            <span class="port-label">P: {{ ports[i] }}</span>
                            <span id="ms-{{i}}" class="latency-tag">测速中</span>
                        </div>
                        <div class="row text-center mb-2 small">
                            <div class="col-6 border-end border-secondary">
                                <div class="text-muted">下载 ↓</div>
                                <div class="text-success fw-bold" id="down-{{i}}">0K</div>
                            </div>
                            <div class="col-6">
                                <div class="text-muted">上传 ↑</div>
                                <div class="text-info fw-bold" id="up-{{i}}">0K</div>
                            </div>
                        </div>
                        <input type="text" name="p{{i}}" value="{{configs[i]}}" class="form-control form-control-sm" placeholder="账号:密码@IP:端口">
                    </div>
                </div>
                {% endfor %}
            </div>
            <button type="submit" class="btn btn-info w-100 mt-4 py-2 fw-bold text-dark shadow-lg">🚀 部署大师级矩阵配置</button>
        </form>
    </div>
    <script>
        const n = {{ n }};
        function addNode() { fetch('/add_node', {method: 'POST'}).then(() => window.location.reload()); }
        function update(i) {
            fetch('/stats/' + i).then(r => r.json()).then(d => {
                document.getElementById('up-'+i).innerText = d.up;
                document.getElementById('down-'+i).innerText = d.down;
                if(d.ms !== "keep") document.getElementById('ms-'+i).innerText = d.ms;
            });
        }
        setInterval(() => { for(let i=0; i<n; i++) update(i); }, 2000);
        window.onload = () => { for(let i=0; i<n; i++) update(i); };
    </script>
</body>
</html>
"""

def load_data():
    p, c = [10001, 10002, 10003, 10004, 10005], [""] * 5
    if os.path.exists(PORTS_FILE):
        with open(PORTS_FILE, 'r') as f: p = json.load(f)
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, 'r') as f: c = json.load(f)
    while len(c) < len(p): c.append("")
    return p, c

@app.route('/stats/<int:idx>')
def stats(idx):
    ports, _ = load_data()
    if idx >= len(ports): return jsonify({"up": "0K", "down": "0K", "ms": "keep"})
    port = ports[idx]
    global last_io, last_ms_time
    try:
        cmd = f"ss -tin state established '( sport = :{port} )'"
        output = subprocess.check_output(cmd, shell=True).decode('utf-8')
        raw_sent = sum([int(m) for m in re.findall(r'bytes_sent:(\d+)', output)])
        raw_recv = sum([int(m) for m in re.findall(r'bytes_received:(\d+)', output)])
        now = time.time()
        
        with io_lock: # 线程锁保护
            prev = last_io.get(idx, (raw_sent, raw_recv, now))
            # 防负数保护
            diff_sent, diff_recv = max(0, raw_sent - prev[0]), max(0, raw_recv - prev[1])
            dt = max(0.1, now - prev[2])
            last_io[idx] = (raw_sent, raw_recv, now)
            
        ms_val = "keep" # 解决延迟闪现问题
        if now - last_ms_time.get(idx, 0) > 10:
            try:
                curl_cmd = ["curl", "-x", f"socks5h://127.0.0.1:{port}", "-o", "/dev/null", "-s", "-w", "%{time_total}", "--connect-timeout", "2", "http://www.baidu.com"]
                res = subprocess.check_output(curl_cmd).decode('utf-8').strip()
                ms_val = f"{int(float(res) * 1000)}ms" if res else "超时"
            except: ms_val = "超时"
            last_ms_time[idx] = now
            
        return jsonify({
            "up": f"{round(diff_recv/dt/1024, 1)}K", 
            "down": f"{round(diff_sent/dt/1024, 1)}K", 
            "ms": ms_val
        })
    except: return jsonify({"up": "0K", "down": "0K", "ms": "错误"})

@app.route('/add_node', methods=['POST'])
def add_node():
    p, c = load_data()
    new_port = max(p) + 1 if p else 10001
    p.append(new_port); c.append("")
    with open(PORTS_FILE, 'w') as f: json.dump(p, f)
    with open(CONFIG_FILE, 'w') as f: json.dump(c, f)
    return jsonify({"status": "success"})

@app.route('/', methods=['GET', 'POST'])
def index():
    ports, configs = load_data()
    if request.method == 'POST':
        new_configs = [request.form.get(f'p{i}') for i in range(len(ports))]
        with open(CONFIG_FILE, 'w') as f: json.dump(new_configs, f)
        subprocess.run(["pkill", "-15", "gost"]) # 优雅退出
        time.sleep(1.5)
        for i, addr in enumerate(new_configs):
            if addr.strip():
                # 改用 Popen 工业级启动
                with open("/var/log/gost.log", "a") as logf:
                    subprocess.Popen(["/usr/local/bin/gost", "-L", f":{ports[i]}", "-F", f"socks5://{addr}"], stdout=logf, stderr=logf)
        return '<script>alert("大师矩阵部署成功！"); window.location.href="/";</script>'
    return render_template_string(HTML_TEMPLATE, ports=ports, configs=configs, n=len(ports))
EOF

# 4. 优化 Systemd 服务：引入 gthread 并发引擎与超时保护
cat <<EOF > /etc/systemd/system/proxy-web.service
[Unit]
Description=Cyber Proxy Matrix V7.5 Master Edition
After=network.target

[Service]
WorkingDirectory=/root
ExecStart=/usr/bin/gunicorn --workers 1 --worker-class gthread --threads 4 --bind 0.0.0.0:8888 --timeout 30 --keep-alive 5 proxy_manager:app
Restart=always
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOF

# 5. 部署日志轮转：防止磁盘爆满
cat <<EOF > /etc/logrotate.d/proxy-matrix
/var/log/proxy_panel.log
/var/log/gost.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
EOF

systemctl daemon-reload
systemctl restart proxy-web
echo "------------------------------------------------"
echo "✅ V7.5 大师矩阵版部署完成！"
echo "✅ 访问地址: http://$(hostname -I | awk '{print $1}'):8888"

echo "------------------------------------------------"
