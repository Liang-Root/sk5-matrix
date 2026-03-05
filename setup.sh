#!/bin/bash
set -e

# [环境安装：强制开启系统包突破]
apt update && apt install python3 python3-pip python3-psutil curl iproute2 gunicorn logrotate -y
pip3 install flask gunicorn --break-system-packages --quiet

# [初始化存储文件]
touch /root/proxy_config.json /root/proxy_ports.json /root/proxy_modes.json
chmod 666 /root/proxy_config.json /root/proxy_ports.json /root/proxy_modes.json

# [生成 Python 核心：V8.0 双模版]
cat <<'EOF' > /root/proxy_manager.py
from flask import Flask, request, render_template_string, jsonify
import subprocess, os, json, time, re, logging, threading

logging.basicConfig(filename='/var/log/proxy_panel.log', level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
app = Flask(__name__)
CONFIG_FILE, PORTS_FILE, MODES_FILE = '/root/proxy_config.json', '/root/proxy_ports.json', '/root/proxy_modes.json'
io_lock = threading.Lock() # 线程安全锁

def load_data():
    p, c, m = [10001, 10002, 10003, 10004, 10005], [""] * 5, ["proxy"] * 5
    if os.path.exists(PORTS_FILE):
        with open(PORTS_FILE, 'r') as f: p = json.load(f)
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, 'r') as f: c = json.load(f)
    if os.path.exists(MODES_FILE):
        with open(MODES_FILE, 'r') as f: m = json.load(f)
    while len(c) < len(p): c.append("")
    while len(m) < len(p): m.append("proxy")
    return p, c, m

HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <title>五脉神剑 V8.0 | 直播矩阵专用</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        body { background: #020617; color: #38bdf8; font-family: sans-serif; }
        .card { background: rgba(15, 23, 42, 0.95); border: 1px solid #0ea5e9; border-radius: 12px; margin-bottom: 20px; }
        .port-label { font-family: monospace; font-size: 1.1rem; font-weight: bold; color: #fff; }
        .form-check-input:checked { background-color: #0ea5e9; border-color: #0ea5e9; }
    </style>
</head>
<body class="p-4">
    <div class="container">
        <div class="d-flex justify-content-between align-items-center mb-4">
            <h2 class="fw-bold text-white mb-0">PROXY MATRIX V8.0</h2>
            <button type="button" class="btn btn-outline-info" onclick="addNode()">+ 增加节点</button>
        </div>
        <form method="post">
            <div class="row g-3">
                {% for i in range(n) %}
                <div class="col-md-6 col-lg-4"><div class="card p-3">
                    <div class="d-flex justify-content-between">
                        <span class="port-label">P: {{ ports[i] }}</span>
                        <div class="form-check form-switch">
                            <input class="form-check-input" type="checkbox" name="m{{i}}" value="direct" {% if modes[i] == 'direct' %}checked{% endif %}>
                            <label class="small text-light ms-1">强制直连</label>
                        </div>
                    </div>
                    <div class="d-flex justify-content-around my-2 small">
                        <span class="text-success">↓ <b id="down-{{i}}">0K</b></span>
                        <span class="text-info">↑ <b id="up-{{i}}">0K</b></span>
                    </div>
                    <input type="text" name="p{{i}}" value="{{configs[i]}}" placeholder="账号:密码@IP:端口" class="form-control form-control-sm bg-black text-info border-secondary">
                </div></div>
                {% endfor %}
            </div>
            <button type="submit" class="btn btn-info w-100 mt-4 fw-bold">🚀 部署大师级矩阵配置</button>
        </form>
    </div>
    <script>
        const n = {{ n }};
        function addNode() { fetch('/add_node', {method: 'POST'}).then(() => window.location.reload()); }
        function update(i) {
            fetch('/stats/' + i).then(r => r.json()).then(d => {
                document.getElementById('up-'+i).innerText = d.up;
                document.getElementById('down-'+i).innerText = d.down;
            });
        }
        setInterval(() => { for(let i=0; i<n; i++) update(i); }, 2000);
    </script>
</body>
</html>
"""

@app.route('/')
def home():
    ports, configs, modes = load_data()
    return render_template_string(HTML_TEMPLATE, ports=ports, configs=configs, modes=modes, n=len(ports))

@app.route('/stats/<int:idx>')
def stats(idx):
    ports, _, _ = load_data()
    port = ports[idx]
    try:
        cmd = f"ss -tin state established '( sport = :{port} )'"
        output = subprocess.check_output(cmd, shell=True).decode('utf-8')
        raw_sent = sum([int(m) for m in re.findall(r'bytes_sent:(\d+)', output)])
        raw_recv = sum([int(m) for m in re.findall(r'bytes_received:(\d+)', output)])
        return jsonify({"up": f"{round(raw_recv/1024, 1)}K", "down": f"{round(raw_sent/1024, 1)}K"})
    except: return jsonify({"up": "0K", "down": "0K"})

@app.route('/add_node', methods=['POST'])
def add_node():
    p, c, m = load_data()
    p.append(max(p) + 1 if p else 10001); c.append(""); m.append("proxy")
    with open(PORTS_FILE, 'w') as f: json.dump(p, f)
    with open(CONFIG_FILE, 'w') as f: json.dump(c, f)
    with open(MODES_FILE, 'w') as f: json.dump(m, f)
    return jsonify({"status": "success"})

@app.route('/', methods=['POST'])
def index():
    ports, _, _ = load_data()
    new_configs = [request.form.get(f'p{i}', '') for i in range(len(ports))]
    new_modes = ["direct" if request.form.get(f'm{i}') == "direct" else "proxy" for i in range(len(ports))]
    
    with open(CONFIG_FILE, 'w') as f: json.dump(new_configs, f)
    with open(MODES_FILE, 'w') as f: json.dump(new_modes, f)
    
    subprocess.run(["pkill", "-15", "gost"])
    time.sleep(1)
    
    for i, addr in enumerate(new_configs):
        addr = addr.strip()
        with open("/var/log/gost.log", "a") as logf:
            if new_modes[i] == "proxy" and addr:
                subprocess.Popen(["/usr/local/bin/gost", "-L", f":{ports[i]}", "-F", f"socks5://{addr}"], stdout=logf, stderr=logf)
            else:
                subprocess.Popen(["/usr/local/bin/gost", "-L", f":{ports[i]}"], stdout=logf, stderr=logf)
    return '<script>alert("V8.0 矩阵部署成功！"); window.location.href="/";</script>'

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8888)
EOF

# [注册 Systemd 服务]
cat <<EOF > /etc/systemd/system/proxy-web.service
[Unit]
Description=Cyber Proxy Matrix V8.0
After=network.target

[Service]
WorkingDirectory=/root
ExecStart=/usr/bin/gunicorn --workers 1 --worker-class gthread --threads 4 --bind 0.0.0.0:8888 --timeout 30 proxy_manager:app
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl restart proxy-web
echo "------------------------------------------------"
echo "✔️ V8.0 大师矩阵版（双模切换）更新完成！"
echo "✔️ 访问地址: http://$(hostname -I | awk '{print $1}'):8888"
echo "------------------------------------------------"
