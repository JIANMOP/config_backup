function proxy() {
    local SHARE_IP="127.0.0.1"
    local PROXY_PORT="7890"
    local SOCKS5_PORT="7890"
    local PROXY_URL="http://$SHARE_IP:$PROXY_PORT"

    if [ "$1" = "on" ]; then
        # 开启代理：设置HTTP/HTTPS/SOCKS5代理环境变量
        export http_proxy="$PROXY_URL"
        export https_proxy="$PROXY_URL"
        export all_proxy="socks5://$SHARE_IP:$SOCKS5_PORT"
        export NO_PROXY="127.0.0.1,localhost,172.0.0.0/8,10.0.0.0/8,192.168.0.0/16,.svc,.cluster.local"
        export no_proxy="$NO_PROXY"
        echo -e "✅ 共享IP代理已开启"
        echo -e "服务器：$SHARE_IP:$PROXY_PORT"

    elif [ "$1" = "off" ]; then
        # 关闭代理：清空代理环境变量
        unset http_proxy https_proxy all_proxy no_proxy
        echo -e "❌ 共享IP代理已关闭"

    elif [ "$1" = "status" ]; then
        # 查看代理状态 + 显示公网IP
        echo -e "\n=== 代理状态 ==="
        if [ -n "$http_proxy" ]; then
            echo -e "✅ 当前代理状态：已开启"
            echo "HTTP  代理：$http_proxy"
            echo "HTTPS 代理：$https_proxy"
            [ -n "$all_proxy" ] && echo "SOCKS5代理：$all_proxy"
        else
            echo -e "❌ 当前代理状态：已关闭"
        fi

        echo -e "\n=== 公网 IP 信息 ==="
        # 自动根据代理状态决定是否走代理查询 IP
        if [ -n "$http_proxy" ]; then
            curl -x "$http_proxy" -s ipinfo.io
        else
            curl -s ipinfo.io
        fi
        echo -e "\n"

    else
        # 提示用法
        echo -e "\n📌 局域网代理开关用法："
        echo "  proxy on     - 开启代理（连接共享IP端口）"
        echo "  proxy off    - 关闭代理"
        echo "  proxy status - 查看代理状态 + 公网IP信息"
        echo ""
    fi
}
