#!/bin/bash

# 显示SSH连接信息（Termux 专属，仅用 ifconfig 提取wlan0 IP）
echo "═══════════════════════════════════════"
echo "用户: $(whoami)"
echo "SSH端口: 8022"

# 核心逻辑：先筛选wlan0相关段落，再提取IP（忽略权限警告）
wlan0_ip=$(ifconfig 2>/dev/null | grep -A 10 "wlan0:" | grep -v "Permission denied" | grep -oE 'inet\s+([0-9]+\.){3}[0-9]+' | grep -v '127\.' | awk '{print $2}')

# 判断是否获取到有效IP
if [ -n "$wlan0_ip" ]; then
    echo "wlan0 IP: $wlan0_ip"
else
    echo "wlan0: 未连接WiFi或未获取IP"
fi

echo "═══════════════════════════════════════"

# 检查SSHD状态
check_sshd() {
    if pgrep -x "sshd" >/dev/null; then
        echo -e "🔵 sshd状态: \033[32m运行中 (PID: $(pgrep -x "sshd"))\033[0m"
        return 0
    else
        echo -e "🟡 sshd状态: \033[33m未运行\033[0m"
        return 1
    fi
}

# 主逻辑
if ! check_sshd; then
    echo -n "▶ 尝试启动sshd..."
    if sshd >/dev/null 2>&1; then
        sleep 1 # 等待进程启动
        if check_sshd; then
            echo -e "\033[32m 成功\033[0m"
        else
            echo -e "\033[31m 失败 (可能端口冲突或权限问题)\033[0m"
        fi
    else
        echo -e "\033[31m 启动命令执行失败\033[0m"
    fi
fi
