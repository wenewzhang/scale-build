#!/bin/sh

# 获取内网IP（优先使用 hostname -I，如果不支持则使用 ip 命令）
if command -v hostname >/dev/null 2>&1 && hostname -I >/dev/null 2>&1; then
    IP=$(hostname -I | awk '{print $1}')
elif command -v ip >/dev/null 2>&1; then
    IP=$(ip route get 1 2>/dev/null | awk '{print $7; exit}')
    if [ -z "$IP" ]; then
        IP=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d'/' -f1 | head -n1)
    fi
elif command -v ifconfig >/dev/null 2>&1; then
    IP=$(ifconfig | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | head -n1)
else
    IP="0.0.0.0"
fi

# 设置端口号
PORT=8000

echo "=================================="
echo "文件分享服务已启动"
echo "访问地址: http://${IP}:${PORT}/ti.tar.gz"
echo "=================================="
echo "按 Ctrl+C 停止服务"
echo ""

# 使用 Python3 启动简单 HTTP 服务器
cd "$(dirname "$0")"
python3 -m http.server ${PORT} --bind ${IP}
