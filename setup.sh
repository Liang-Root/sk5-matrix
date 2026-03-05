#!/bin/bash
set -e

# [环境加固]
apt update && apt install python3 python3-pip python3-psutil curl iproute2 gunicorn logrotate -y
pip3 install flask gunicorn --break-system-packages --quiet

# [数据持久化：只有文件不存在时才初始化，更新不丢数据]
[ ! -f /root/proxy_config.json ] && echo "[]" > /root/proxy_config.json
[ ! -f /root/proxy_ports.json ] && echo "[]" > /root/proxy_ports.json
[ ! -f /root/proxy_modes.json ] && echo "[]" > /root/proxy_modes.json
chmod 666 /root/*.json

# [生成 Python 核心：V8.2 逻辑修正版]
cat <<'EOF' > /root/proxy_manager.py
from flask import Flask, request, render_template_string, jsonify
import subprocess, os, json, time, re, threading

app = Flask(__name__)
CONFIG_FILE, PORTS_FILE, MODES_FILE = '/root/proxy_config.json', '/root/proxy_ports.json', '/root/proxy_modes.json'
last_ms_time = {}

def load_data():
    p, c, m = [10001, 10002, 10003, 10004, 10005], [], []
    try:
        with open(PORTS_FILE, 'r') as f: p = json.load(f) or p
        with open(CONFIG_FILE, 'r') as f: c = json.load(f) or [""] * len(p)
        with open(MODES_FILE, 'r') as f: m = json.load(f) or ["proxy"] * len(p)
    except: pass
    while len(c) < len(p): c.append("")
    while len(m) < len(p): m.append("proxy")
    return p, c, m

HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <title>五脉神剑 V8.2 | 逻辑修正版</title>
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
            <h2 class="fw-bold text-white mb-0">PROXY MATRIX V8.2</h2>
            <button type="button" class="btn btn-outline-info" onclick="addNode()">+ 增加节点</button>
        </div>
        <form method="post">
            <div class="row g-3">
                {% for i in range(n) %}
                <div class="col-md-6 col-lg-4"><div class="card p-3">
                    <div class="d-flex justify-content-between align-items-center">
                        <span class="port-label">P: {{ ports[i] }}</span>
                        <div class="d-flex align-items-center">
                            <span id="ms-{{i}}" class="badge bg-dark text-warning me-2" style="font-size:0.7rem;">测速中</span>
                            <div class="form-check form-switch mb-0">
                                <input class="form-check-input" type="checkbox" name="m{{i}}" value="proxy" {% if modes[i] == 'proxy' %}checked{% endif %}>
                                <label class="small text-light ms-1">代理</label>
                            </div>
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
            <button type="submit" class="btn btn-info w-100 mt-4 fw-bold">🚀 部署配置（On=代理 / Off=直连）</button>
        </form>
    </div>
    <script>
        const n = {{ n }};
        function addNode() { fetch('/add_node', {method: 'POST'}).then(() => window.location.reload()); }
        function update(i) {
            fetch('/stats/' + i).then(r => r.json()).then(d => {
                document.getElementById('up-'+i).innerText = d.up;
                document.getElementById('down-'+i).innerText = d.down;
                if(d.ms !== "keep") {
                    const el = document.getElementById('ms-'+i);
                    el.innerText = d.ms;
                    el.className = d.ms === "超时" ? "badge bg-danger text-white" : "badge bg-dark text-warning";
                }
            });
        }
        setInterval(() => { for(let i=0; i<n; i++) update(i); }, 2000);
    </script>
</body>
</html>
"""

@app.route('/')
def index_view():
    p, c, m = load_data()
    return render_template_string(HTML_TEMPLATE, ports=p, configs=c, modes=m, n=len(p))

@app.route('/stats/<int:idx>')
def stats(idx):
    ports, _, _ = load_data()
    port = ports[idx]
    global last_ms_time
    try:
        cmd = f"ss -tin state established '( sport = :{port} )'"
        output = subprocess.check_output(cmd, shell=True).decode('utf-8')
        raw_sent = sum([int(m) for m in re.findall(r'bytes_sent:(\d+)', output)])
        raw_recv = sum([int(m) for m in re.findall(r'bytes_received:(\d+)', output)])
        now = time.time()
        ms_val = "keep"
        if now - last_ms_time.get(idx, 0) > 10:
            try:
                res = subprocess.check_output(["curl", "-x", f"socks5h://127.0.0.1:{port}", "-o", "/dev/null", "-s", "-w", "%{time_total}", "--connect-timeout", "2", "http://www.baidu.com"]).decode('utf-8').strip()
                ms_val = f"{int(float(res) * 1000)}ms" if res else "超时"
            except: ms_val = "超时"
            last_ms_time[idx] = now
        return jsonify({"up": f"{round(raw_recv/1024, 1)}K", "down": f"{round(raw_sent/1024, 1)}K", "ms": ms_val})
    except: return jsonify({"up": "0K", "down": "0K", "ms": "错误"})

@app.route('/add_node', methods=['POST'])
def add_node():
    p, c, m = load_data()
    p.append(max(p) + 1 if p else 10001); c.append(""); m.append("proxy")
    with open(PORTS_FILE, 'w') as f: json.dump(p, f)
    with open(CONFIG_FILE, 'w') as f: json.dump(c, f)
    with open(MODES_FILE, 'w') as f: json.dump(m, f)
    return jsonify({"status": "success"})

@app.route('/', methods=['POST'])
def deploy():
    ports, _, _ = load_data()
    new_configs = [request.form.get(f'p{i}', '') for i in range(len(ports))]
    # 逻辑修正：接收来自 HTML 的 proxy 信号
    new_modes = ["proxy" if request.form.get(f'm{i}') == "proxy" else "direct" for i in range(len(ports))]
    with open(CONFIG_FILE, 'w') as f: json.dump(new_configs, f)
    with open(MODES_FILE, 'w') as f: json.dump(new_modes, f)
    
    subprocess.run(["pkill", "-15", "gost"])
    time.sleep(1)
    for i, addr in enumerate(new_configs):
        addr = addr.strip()
        with open("/var/log/gost.log", "a") as logf:
            # 逻辑判定：只有处于 proxy 模式且填了地址，才走二级转发
            if new_modes[i] == "proxy" and addr:
                subprocess.Popen(["/usr/local/bin/gost", "-L", f":{ports[i]}", "-F", f"socks5://{addr}"], stdout=logf, stderr=logf)
            else:
                subprocess.Popen(["/usr/local/bin/gost", "-L", f":{ports[i]}"], stdout=logf, stderr=logf)
    return '<script>alert("V8.2 逻辑修正版部署成功！"); window.location.href="/";</script>'

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8888)
EOF

# [注册服务并启动]
systemctl daemon-reload
systemctl restart proxy-web
echo "✔️ V8.2 逻辑修正 + 数据持久化更新完成！"
