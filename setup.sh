#!/bin/bash
set -e

echo "====================================================="
echo "  🚀 正在部署 五脉神剑 V8.6 (SDN 智能增删终极版) 🚀  "
echo "====================================================="

# [1. 环境全自动安装]
apt update && apt install python3 python3-pip python3-psutil curl iproute2 gunicorn logrotate -y
pip3 install flask gunicorn --break-system-packages --quiet

# [2. 下载 Gost 核心（全新安装保障）]
if [ ! -f /usr/local/bin/gost ]; then
    echo "正在下载 Gost 核心..."
    curl -L https://github.com/go-gost/gost/releases/download/v2.11.5/gost-linux-amd64-2.11.5.gz | gunzip > /usr/local/bin/gost
    chmod +x /usr/local/bin/gost
fi

# [3. 数据持久化：更新不丢配置]
[ ! -f /root/proxy_config.json ] && echo "[]" > /root/proxy_config.json
[ ! -f /root/proxy_ports.json ] && echo "[]" > /root/proxy_ports.json
[ ! -f /root/proxy_modes.json ] && echo "[]" > /root/proxy_modes.json
[ ! -f /root/proxy_binds.json ] && echo "[]" > /root/proxy_binds.json
[ ! -f /root/proxy_vlans.json ] && echo "[]" > /root/proxy_vlans.json
chmod 666 /root/*.json

# [4. 生成 Python 核心逻辑：V8.6 完美版]
cat <<'EOF' > /root/proxy_manager.py
from flask import Flask, request, render_template_string, jsonify
import subprocess, os, json, time, re, threading

app = Flask(__name__)

# 智能嗅探主网卡 (解决 eth0/eth1/ens18 等名字不一致问题)
MAIN_IFACE = os.popen("ls /sys/class/net | grep -E '^eth|^ens|^enp|^net' | head -n 1").read().strip() or 'eth0'

CONFIG_FILE = '/root/proxy_config.json'
PORTS_FILE = '/root/proxy_ports.json'
MODES_FILE = '/root/proxy_modes.json'
BINDS_FILE = '/root/proxy_binds.json'
VLANS_FILE = '/root/proxy_vlans.json'
last_ms_time = {}

def load_data():
    p, c, m, b, v = [10001, 10002, 10003, 10004, 10005], [], [], [], []
    try:
        if os.path.exists(PORTS_FILE):
            with open(PORTS_FILE, 'r') as f: p = json.load(f) or p
        if os.path.exists(CONFIG_FILE):
            with open(CONFIG_FILE, 'r') as f: c = json.load(f) or [""] * len(p)
        if os.path.exists(MODES_FILE):
            with open(MODES_FILE, 'r') as f: m = json.load(f) or ["proxy"] * len(p)
        if os.path.exists(BINDS_FILE):
            with open(BINDS_FILE, 'r') as f: b = json.load(f) or [""] * len(p)
        if os.path.exists(VLANS_FILE):
            with open(VLANS_FILE, 'r') as f: v = json.load(f) or [""] * len(p)
    except: pass
    
    while len(c) < len(p): c.append("")
    while len(m) < len(p): m.append("proxy")
    while len(b) < len(p): b.append("")
    while len(v) < len(p): v.append("")
    return p, c, m, b, v

HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <title>五脉神剑 V8.6 | 动态增删完美版</title>
    <link href="https://cdn.staticfile.net/twitter-bootstrap/5.3.0/css/bootstrap.min.css" rel="stylesheet">
    <style>
        body { background: #020617; color: #38bdf8; font-family: sans-serif; }
        .card { background: rgba(15, 23, 42, 0.95); border: 1px solid #0ea5e9; border-radius: 12px; margin-bottom: 20px; transition: 0.2s; }
        .card:hover { border-color: #38bdf8; box-shadow: 0 0 10px rgba(56,189,248,0.3); }
        .port-label { font-family: monospace; font-size: 1.1rem; font-weight: bold; color: #fff; }
        .form-check-input:checked { background-color: #0ea5e9; border-color: #0ea5e9; }
        .sdn-panel { background: #0f172a; border: 1px dashed #eab308; padding: 10px; border-radius: 8px; margin-top: 10px; }
        .btn-del { font-size: 0.75rem; padding: 0.1rem 0.4rem; margin-left: 10px; }
    </style>
</head>
<body class="p-4">
    <div class="container">
        <div class="d-flex justify-content-between align-items-center mb-4">
            <h2 class="fw-bold text-white mb-0">PROXY MATRIX V8.6 <span class="badge bg-danger fs-6 align-middle">SDN 智能接管</span></h2>
            <button type="button" class="btn btn-outline-info" onclick="addNode()">+ 增加新节点</button>
        </div>
        <form method="post" id="mainForm">
            <div class="row g-3">
                {% for i in range(n) %}
                <div class="col-md-6 col-lg-4" id="node-{{i}}"><div class="card p-3">
                    <div class="d-flex justify-content-between align-items-center mb-2">
                        <span class="port-label" id="port-{{i}}">P: {{ ports[i] }}</span>
                        <div class="d-flex align-items-center">
                            <span id="ms-{{i}}" class="badge bg-dark text-warning me-2" style="font-size:0.7rem;">测速中</span>
                            <div class="form-check form-switch mb-0">
                                <input class="form-check-input" type="checkbox" name="m{{i}}" value="proxy" {% if modes[i] == 'proxy' %}checked{% endif %}>
                            </div>
                            <button type="button" class="btn btn-outline-danger btn-del" onclick="delNode({{i}})" title="彻底销毁此节点及网卡">✖</button>
                        </div>
                    </div>
                    <div class="d-flex justify-content-around mb-2 small">
                        <span class="text-success">↓ <b id="down-{{i}}">0K</b></span>
                        <span class="text-info">↑ <b id="up-{{i}}">0K</b></span>
                    </div>
                    
                    <input type="text" name="p{{i}}" value="{{configs[i]}}" placeholder="账号:密码@代理IP:端口" class="form-control form-control-sm bg-black text-info border-secondary mb-2" title="上游SK5节点">
                    
                    <div class="sdn-panel">
                        <div class="row g-1">
                            <div class="col-4">
                                <input type="text" name="v{{i}}" value="{{vlans[i]}}" placeholder="VLAN ID" class="form-control form-control-sm bg-black text-warning border-secondary text-center" title="如: 60">
                            </div>
                            <div class="col-8">
                                <input type="text" name="b{{i}}" value="{{binds[i]}}" placeholder="本地IP (如:192.168.60.253)" class="form-control form-control-sm bg-black text-warning border-secondary" title="对应 VLAN 的本地 IP">
                            </div>
                        </div>
                        <div class="text-end mt-1"><small class="text-secondary" style="font-size:0.65rem;">主网卡: {{ main_iface }}</small></div>
                    </div>
                </div></div>
                {% endfor %}
            </div>
            <button type="submit" class="btn btn-warning w-100 mt-4 fw-bold text-dark">⚙️ 重建网络并部署（自动增删底层虚拟网卡）</button>
        </form>
    </div>
    <script>
        const n = {{ n }};
        function addNode() { fetch('/add_node', {method: 'POST'}).then(() => window.location.href='/'); }
        
        function delNode(idx) {
            const portName = document.getElementById('port-'+idx).innerText;
            // 完美解决换行导致的 JS 报错（使用 ES6 模板字符串）
            if(confirm(`🚨 危险操作！\n\n确定要销毁节点 [${portName}] 吗？\n如果配置了 VLAN，底层网卡也会被强制拆除！`)) {
                fetch('/del_node/' + idx, {method: 'POST'}).then(() => window.location.href='/');
            }
        }

        function update(i) {
            fetch('/stats/' + i).then(r => r.json()).then(d => {
                const elUp = document.getElementById('up-'+i);
                if(elUp) elUp.innerText = d.up;
                const elDown = document.getElementById('down-'+i);
                if(elDown) elDown.innerText = d.down;
                if(d.ms !== "keep") {
                    const elMs = document.getElementById('ms-'+i);
                    if(elMs) {
                        elMs.innerText = d.ms;
                        elMs.className = d.ms === "超时" ? "badge bg-danger text-white me-2" : "badge bg-dark text-warning me-2";
                    }
                }
            }).catch(e=>{});
        }
        setInterval(() => { for(let i=0; i<n; i++) update(i); }, 2000);
    </script>
</body>
</html>
"""

@app.route('/')
def index_view():
    p, c, m, b, v = load_data()
    return render_template_string(HTML_TEMPLATE, ports=p, configs=c, modes=m, binds=b, vlans=v, n=len(p), main_iface=MAIN_IFACE)

@app.route('/stats/<int:idx>')
def stats(idx):
    ports, _, _, _, _ = load_data()
    if idx >= len(ports): return jsonify({"up": "0K", "down": "0K", "ms": "已删除"})
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
    p, c, m, b, v = load_data()
    p.append(max(p) + 1 if p else 10001); c.append(""); m.append("proxy"); b.append(""); v.append("")
    with open(PORTS_FILE, 'w') as f: json.dump(p, f)
    with open(CONFIG_FILE, 'w') as f: json.dump(c, f)
    with open(MODES_FILE, 'w') as f: json.dump(m, f)
    with open(BINDS_FILE, 'w') as f: json.dump(b, f)
    with open(VLANS_FILE, 'w') as f: json.dump(v, f)
    return jsonify({"status": "success"})

@app.route('/del_node/<int:idx>', methods=['POST'])
def del_node(idx):
    p, c, m, b, v = load_data()
    if 0 <= idx < len(p):
        vlan_to_del = str(v[idx]).strip()
        p.pop(idx); c.pop(idx); m.pop(idx); b.pop(idx); v.pop(idx)
        with open(PORTS_FILE, 'w') as f: json.dump(p, f)
        with open(CONFIG_FILE, 'w') as f: json.dump(c, f)
        with open(MODES_FILE, 'w') as f: json.dump(m, f)
        with open(BINDS_FILE, 'w') as f: json.dump(b, f)
        with open(VLANS_FILE, 'w') as f: json.dump(v, f)
        # 后台异步销毁网卡
        threading.Thread(target=apply_network_and_proxy, args=(p, c, m, b, v, [vlan_to_del])).start()
    return jsonify({"status": "success"})

def apply_network_and_proxy(ports, configs, modes, binds, vlans, old_vlans=[]):
    # 停止全部代理服务
    subprocess.run(["pkill", "-15", "gost"])
    
    # 清理被删除或废弃的子网卡
    for v_id in old_vlans:
        if v_id and str(v_id).isdigit():
            os.system(f"ip link delete {MAIN_IFACE}.{v_id} 2>/dev/null")
            
    time.sleep(1)
    
    # 重建新网卡并启动代理
    for i, addr in enumerate(configs):
        vlan_id = str(vlans[i]).strip()
        bind_ip = str(binds[i]).strip()
        bind_suffix = f"?bind={bind_ip}" if bind_ip else ""
        
        if vlan_id.isdigit() and bind_ip:
            iface_name = f"{MAIN_IFACE}.{vlan_id}"
            os.system(f"ip link add link {MAIN_IFACE} name {iface_name} type vlan id {vlan_id} 2>/dev/null")
            os.system(f"ip addr add {bind_ip}/24 dev {iface_name} 2>/dev/null")
            os.system(f"ip link set dev {iface_name} up 2>/dev/null")
            
        with open("/var/log/gost.log", "a") as logf:
            if modes[i] == "proxy" and addr:
                cmd = ["/usr/local/bin/gost", "-L", f"socks5://0.0.0.0:{ports[i]}", "-F", f"socks5://{addr}{bind_suffix}"]
                subprocess.Popen(cmd, stdout=logf, stderr=logf)
            else:
                cmd = ["/usr/local/bin/gost", "-L", f"socks5://0.0.0.0:{ports[i]}"]
                if bind_suffix:
                    cmd.extend(["-F", f"direct://{bind_suffix}"])
                subprocess.Popen(cmd, stdout=logf, stderr=logf)

@app.route('/', methods=['POST'])
def deploy():
    _, _, _, _, old_vlans = load_data()
    ports, _, _, _, _ = load_data()
    
    new_configs = [request.form.get(f'p{i}', '').strip() for i in range(len(ports))]
    new_modes = ["proxy" if request.form.get(f'm{i}') == "proxy" else "direct" for i in range(len(ports))]
    new_binds = [request.form.get(f'b{i}', '').strip() for i in range(len(ports))]
    new_vlans = [request.form.get(f'v{i}', '').strip() for i in range(len(ports))]
    
    with open(CONFIG_FILE, 'w') as f: json.dump(new_configs, f)
    with open(MODES_FILE, 'w') as f: json.dump(new_modes, f)
    with open(BINDS_FILE, 'w') as f: json.dump(new_binds, f)
    with open(VLANS_FILE, 'w') as f: json.dump(new_vlans, f)
    
    threading.Thread(target=apply_network_and_proxy, args=(ports, new_configs, new_modes, new_binds, new_vlans, old_vlans)).start()
    
    # 采用 ES6 语法，彻底告别弹窗白屏
    return '<script>alert(`V8.6 配置已更新！\n底层网络与代理正在重组...`); window.location.href="/";</script>'

if __name__ == '__main__':
    p, c, m, b, v = load_data()
    apply_network_and_proxy(p, c, m, b, v, old_vlans=[])
    app.run(host='0.0.0.0', port=8888)
EOF

# [5. 注册为底层服务，确保开机自启]
cat <<EOF > /etc/systemd/system/proxy-web.service
[Unit]
Description=Cyber Proxy Matrix V8.6 Master SDN
After=network.target

[Service]
WorkingDirectory=/root
ExecStart=/usr/bin/gunicorn --workers 1 --worker-class gthread --threads 4 --bind 0.0.0.0:8888 --timeout 30 proxy_manager:app
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# [6. 激活服务并收尾]
systemctl daemon-reload
systemctl enable proxy-web
systemctl restart proxy-web

echo "------------------------------------------------"
echo "✔️  V8.6 SDN 智能终极版 安装完成！"
echo "✔️  已修复：销毁按钮逻辑 (自动注销底层 VLAN 网卡)"
echo "✔️  已修复：网卡智能嗅探 (完美适配 eth1, ens18 等)"
echo "✔️  数据未丢失，刷新网页即可起飞！"
echo "------------------------------------------------"
