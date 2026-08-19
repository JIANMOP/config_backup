#!/data/data/com.termux/files/usr/bin/bash
# Re‑implement from https://github.com/JIANMOP/config_backup/blob/main/ubuntu/scripts/ssh_trust.sh
# Termux adaptation, remove whiptail, sudo

SSH_DIR="$HOME/.ssh"
IDENTITY_FILE="$SSH_DIR/id_rsa"
CONFIG_FILE="$SSH_DIR/config"

init_dir(){
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    [ ! -f "$CONFIG_FILE" ] && touch "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
}

generate_key(){
    if [ -f "$IDENTITY_FILE" ];then
        read -p "密钥已存在，是否覆盖(y/N): " res
        [[ "${res,,}" != "y" ]] && return
    fi
    echo "正在生成 RSA 密钥对"
    ssh-keygen -t rsa -b 4096 -f "$IDENTITY_FILE" -N ""
    chmod 600 "$IDENTITY_FILE"
    echo "密钥生成完成"
}

show_pubkey(){
    local pub="${IDENTITY_FILE}.pub"
    if [ ! -f "$pub" ];then
        echo "公钥不存在，请先生成密钥"
        return
    fi
    echo -e "\n$(cat "$pub")\n"
}

list_hosts(){
    grep '^Host ' "$CONFIG_FILE" | awk '{print $2}'
}

push_by_host(){
    local hosts=()
    while IFS= read -r line; do
        hosts+=("$line")
    done < <(list_hosts)
    if [ ${#hosts[@]} -eq 0 ];then
        echo "config文件暂无主机，请先添加主机"
        return
    fi
    echo "主机列表:"
    for i in "${!hosts[@]}";do
        echo "$((i+1)). ${hosts[$i]}"
    done
    read -p "选择序号: " sel
    idx=$((sel-1))
    if (( idx <0 || idx >= ${#hosts[@]} ));then
        echo "无效选择"
        return
    fi
    local hname="${hosts[$idx]}"
    echo "推送公钥到 $hname"
    ssh-copy-id "$hname"
}

add_host(){
    read -p "Host别名: " h
    [[ -z "$h" ]] && return
    read -p "HostName(IP/域名): " hn
    [[ -z "$hn" ]] && return
    read -p "User: " usr
    [[ -z "$usr" ]] && return
    read -p "Port(默认22): " pt
    pt=${pt:-22}
    cat >> "$CONFIG_FILE" <<_EOT_
Host $h
    HostName $hn
    User $usr
    Port $pt

_EOT_
    chmod 600 "$CONFIG_FILE"
    echo "主机已添加"
}

del_host(){
    local hosts=()
    while IFS= read -r line; do
        hosts+=("$line")
    done < <(list_hosts)
    if [ ${#hosts[@]} -eq 0 ];then
        echo "没有主机记录"
        return
    fi
    echo "主机列表:"
    for i in "${!hosts[@]}";do
        echo "$((i+1)). ${hosts[$i]}"
    done
    read -p "删除序号: " sel
    idx=$((sel-1))
    if (( idx <0 || idx >= ${#hosts[@]} ));then
        echo "无效选择"
        return
    fi
    local target="${hosts[$idx]}"
    # 删除整块Host配置
    awk -v h="$target" '
        BEGIN{flag=1}
        $0=="Host "h{flag=0;next}
        flag==0 && /^Host /{flag=1}
        flag==1{print}
    ' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    echo "已删除 $target"
}

main_menu(){
    clear
    echo "====================================="
    echo "1.生成密钥"
    echo "2.推送公钥到已配置主机"
    echo "3.查看本机公钥"
    echo "4.添加主机至 ~/.ssh/config"
    echo "5.删除主机配置"
    echo "0.退出"
    echo "====================================="
    read -p "请选择: " opt
    case "$opt" in
    1) generate_key ;;
    2) push_by_host ;;
    3) show_pubkey ;;
    4) add_host ;;
    5) del_host ;;
    0) echo "退出";exit 0 ;;
    *) echo "无效选项" ;;
    esac
    read -p "按回车继续"
}

main(){
    init_dir
    while true;do
        main_menu
    done
}

main
