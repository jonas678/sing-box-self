#!/bin/bash

export LANG=en_US.UTF-8

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;36m'
plain='\033[0m'

echo_red(){ echo -e "${red}$1${plain}";}
echo_green(){ echo -e "${green}$1${plain}";}
echo_yellow(){ echo -e "${yellow}$1${plain}";}
echo_blue(){ echo -e "${blue}$1${plain}";}

check_installed(){
    if [[ ! -f /etc/s-box/sing-box ]]; then
        echo_red "尚未安裝 sing-box"
        return 1
    fi
    return 0
}

get_node_info(){
    if [[ ! -f /etc/s-box/sb.json ]]; then
        echo_red "配置文件不存在"
        return 1
    fi
    
    uuid=$(jq -r '.inbounds[0].users[0].uuid' /etc/s-box/sb.json)
    port=$(jq -r '.inbounds[0].listen_port' /etc/s-box/sb.json)
    sni=$(jq -r '.inbounds[0].tls.server_name' /etc/s-box/sb.json)
    public_key=$(cat /etc/s-box/public.key 2>/dev/null)
    short_id=$(jq -r '.inbounds[0].tls.reality.short_id[0]' /etc/s-box/sb.json)
    server_ip=$(curl -s4m5 icanhazip.com || curl -s6m5 icanhazip.com)
    
    echo ""
    echo_blue "============================================"
    echo_yellow "  UUID: $uuid"
    echo_yellow "  端口: $port"
    echo_yellow "  SNI: $sni"
    echo_yellow "  公鑰: $public_key"
    echo_yellow "  Short ID: $short_id"
    echo_yellow "  服務器IP: $server_ip"
    echo_blue "============================================"
    
    vl_link="vless://${uuid}@${server_ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${public_key}&sid=${short_id}&type=tcp&headerType=none#VLESS-Reality"
    echo ""
    echo_yellow "分享鏈接:"
    echo "$vl_link"
    echo_blue "============================================"
    echo ""
}

change_port(){
    if ! check_installed; then
        echo_red "sing-box 未安裝"
        return 1
    fi
    
    current_port=$(jq -r '.inbounds[0].listen_port' /etc/s-box/sb.json)
    echo ""
    echo_yellow "目前端口: $current_port"
    echo ""
    echo "輸入新端口 (10000-65535)，或直接回車隨機生成:"
    read -p "請輸入: " new_port
    
    if [[ -z "$new_port" ]]; then
        new_port=$(shuf -i 10000-65535 -n 1)
    fi
    
    if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [[ "$new_port" -lt 1 ]] || [[ "$new_port" -gt 65535 ]]; then
        echo_red "端口無效，請輸入 1-65535之間的數字"
        return 1
    fi
    
    jq --arg port "$new_port" '.inbounds[0].listen_port = ($port | tonumber)' /etc/s-box/sb.json > /tmp/sb.json.tmp && mv /tmp/sb.json.tmp /etc/s-box/sb.json
    
    systemctl restart sing-box
    sleep 2
    
    if systemctl is-active --quiet sing-box; then
        echo_green "端口已更改為: $new_port"
    else
        echo_red "服務重啟失敗，請檢查日誌"
        return 1
    fi
}

install(){
    if check_installed; then
        echo_yellow "sing-box 已安裝"
        read -p "是否重新安裝？(y/n): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            return 0
        fi
    fi

    echo_blue "============================================"
    echo_green "VLESS+Reality 安裝腳本"
    echo_blue "============================================"

    echo_yellow "\n[1/6] 檢測系統環境..."

    if [[ -f /etc/redhat-release ]]; then
        release="Centos"
    elif cat /etc/issue | grep -q -E -i "debian"; then
        release="Debian"
    elif cat /etc/issue | grep -q -E -i "ubuntu"; then
        release="Ubuntu"
    else 
        echo_red "腳本不支持當前系統"
        exit
    fi

    echo_green "檢測到系統: $release"

    echo_yellow "\n是否關閉防火牆？(回車默認: 是)"
    echo "  1、是 (推薦)"
    echo "  2、否"
    read -p "請選擇 [1-2]: " fw_choice

    if [[ -z "$fw_choice" ]] || [[ "$fw_choice" == "1" ]]; then
        echo_green "關閉防火牆..."
        systemctl stop firewalld 2>/dev/null || true
        systemctl disable firewalld 2>/dev/null || true
        ufw disable 2>/dev/null || true
        iptables -P INPUT ACCEPT 2>/dev/null || true
        iptables -P FORWARD ACCEPT 2>/dev/null || true
        iptables -P OUTPUT ACCEPT 2>/dev/null || true
        iptables -F 2>/dev/null || true
        echo_green "防火牆已關閉"
    fi

    case $(uname -m) in
        aarch64) cpu="arm64";;
        x86_64) cpu="amd64";;
        *) echo_red "不支持當前架構"; exit;;
    esac
    echo_green "CPU架構: $cpu"

    echo_yellow "\n[2/6] 安裝系統依賴..."

    if [ -x "$(command -v apt-get)" ]; then
        apt update -y
        apt install -y curl wget tar jq openssl coreutils
    elif [ -x "$(command -v yum)" ]; then
        yum update -y
        yum install -y curl wget tar jq openssl coreutils
    fi

    echo_green "依賴安裝完成"

    echo_yellow "\n[3/6] 下載並安裝 sing-box 內核..."

    mkdir -p /etc/s-box

    sbcore=$(curl -Ls https://github.com/SagerNet/sing-box/releases/latest | grep -oP 'tag/v\K[0-9.]+' | head -n 1)
    echo_green "最新版本: v$sbcore"

    sbname="sing-box-$sbcore-linux-$cpu"
    curl -L -o /etc/s-box/sing-box.tar.gz \
        --retry 2 \
        "https://github.com/SagerNet/sing-box/releases/download/v$sbcore/$sbname.tar.gz"

    if [[ ! -f '/etc/s-box/sing-box.tar.gz' ]]; then
        echo_red "下載失敗，請檢查網絡連接"
        exit
    fi

    tar xzf /etc/s-box/sing-box.tar.gz -C /etc/s-box
    mv /etc/s-box/$sbname/sing-box /etc/s-box
    rm -rf /etc/s-box/sing-box.tar.gz /etc/s-box/$sbname

    chown root:root /etc/s-box/sing-box
    chmod +x /etc/s-box/sing-box

    echo_green "sing-box 安裝成功: $(/etc/s-box/sing-box version | awk '/version/{print $NF}')"

    echo_yellow "\n[4/6] 生成 Reality 密鑰對和 UUID..."

    key_pair=$(/etc/s-box/sing-box generate reality-keypair)
    private_key=$(echo "$key_pair" | awk '/PrivateKey/ {print $2}' | tr -d '"')
    public_key=$(echo "$key_pair" | awk '/PublicKey/ {print $2}' | tr -d '"')
    short_id=$(/etc/s-box/sing-box generate rand --hex 4)
    uuid=$(/etc/s-box/sing-box generate uuid)

    echo_green "公鑰: $public_key"
    echo_green "Short ID: $short_id"
    echo_green "UUID: $uuid"

    echo "$public_key" > /etc/s-box/public.key

    echo_yellow "\n[5/6] 設置端口..."
    echo "輸入端口 (10000-65535)，或直接回車隨機生成:"
    read -p "請輸入: " port_input
    
    if [[ -z "$port_input" ]]; then
        port=$(shuf -i 10000-65535 -n 1)
    else
        if ! [[ "$port_input" =~ ^[0-9]+$ ]] || [[ "$port_input" -lt 1 ]] || [[ "$port_input" -gt 65535 ]]; then
            echo_red "端口無效，使用隨機端口"
            port=$(shuf -i 10000-65535 -n 1)
        else
            port=$port_input
        fi
    fi
    echo_green "端口: $port"

    echo_yellow "\n[6/6] 創建配置文件..."

    sni_domain="apple.com"

    cat > /etc/s-box/sb.json <<EOF
{
  "log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-reality",
      "listen": "::",
      "listen_port": ${port},
      "users": [
        {
          "uuid": "${uuid}",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "${sni_domain}",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "${sni_domain}",
            "server_port": 443
          },
          "private_key": "$private_key",
          "short_id": ["$short_id"]
        }
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "rules": [
      {
        "type": "default",
        "action": "sniff"
      }
    ]
  }
}
EOF

    cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
After=network.target nss-lookup.target

[Service]
User=root
WorkingDirectory=/root
ExecStart=/etc/s-box/sing-box run -c /etc/s-box/sb.json
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable sing-box
    systemctl start sing-box

    sleep 2

    if systemctl is-active --quiet sing-box; then
        echo_green "服務啟動成功"
    else
        echo_red "服務啟動失敗，請檢查日誌"
        exit
    fi

    echo_blue "\n============================================"
    echo_green "安裝完成！"
    echo_blue "============================================"
    get_node_info
}

uninstall(){
    echo ""
    echo_yellow "確認要移除所有安裝的內容嗎？"
    echo "這將會刪除："
    echo "  - sing-box 服務"
    echo "  - 配置文件"
    echo "  - 所有相關檔案"
    echo ""
    read -p "輸入 'yes' 確認刪除: " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        echo_green "取消刪除"
        return 0
    fi
    
    echo_green "正在移除..."
    
    systemctl stop sing-box 2>/dev/null || true
    systemctl disable sing-box 2>/dev/null || true
    rm -f /etc/systemd/system/sing-box.service
    systemctl daemon-reload
    
    rm -rf /etc/s-box
    
    echo_green "已移除所有安裝的內容"
}

menu(){
    while true; do
        check_installed && installed=true || installed=false
        
        echo ""
        echo_blue "============================================"
        echo_green "VLESS+Reality 管理腳本"
        echo_blue "============================================"
        echo ""
        echo "  1. 安裝/重新安裝 sing-box"
        echo "  2. 查看節點信息"
        echo "  3. 修改端口"
        echo "  4. 停止服務"
        echo "  5. 啟動服務"
        echo "  6. 重啟服務"
        echo "  7. 查看服務狀態"
        echo "  8. 移除所有安裝內容"
        echo "  0. 退出"
        echo ""
        echo_blue "============================================"
        
        if [[ "$installed" == "true" ]]; then
            status=$(systemctl is-active sing-box)
            if [[ "$status" == "active" ]]; then
                echo_green "sing-box 狀態: 運行中"
            else
                echo_red "sing-box 狀態: 已停止"
            fi
        else
            echo_red "sing-box 狀態: 未安裝"
        fi
        echo_blue "============================================"
        
        printf "請選擇 [0-8]: "
        read choice
        
        case "$choice" in
            1) install ;;
            2) get_node_info ;;
            3) change_port ;;
            4) systemctl stop sing-box && echo_green "服務已停止" ;;
            5) systemctl start sing-box && echo_green "服務已啟動" ;;
            6) systemctl restart sing-box && sleep 2 && systemctl status sing-box --no-pager | head -10 ;;
            7) systemctl status sing-box --no-pager | head -15 ;;
            8) uninstall ;;
            0) echo_green "再見！" && exit 0 ;;
            *) echo_red "無效選擇，請重新輸入" && continue ;;
        esac
        
        echo ""
        read -r
    done
}

menu
