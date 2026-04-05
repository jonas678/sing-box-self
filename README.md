# VLESS+Reality 一键安装脚本

一个简洁的 VLESS+Reality 协议安装管理脚本，基于 sing-box 内核。

---

## 功能

- ✅ 一键安装 VLESS+Reality
- ✅ 自定义端口
- ✅ 查看节点信息
- ✅ 管理服务（启动/停止/重启）
- ✅ 卸载功能
- ✅ 支持 Ubuntu/Debian/CentOS
- ✅ 支持 amd64/arm64 架构

---

## 安装

```bash
# 方式一：直接运行（推荐）
bash <(wget -qO- https://raw.githubusercontent.com/jonas678/sing-box-self/main/vless-reality.sh)

# 方式二：下载后运行
curl -o /tmp/vless.sh https://raw.githubusercontent.com/jonas678/sing-box-self/main/vless-reality.sh && bash /tmp/vless.sh
```

---

## 脚本详细步骤

### 主菜单

脚本启动后显示主菜单：

```
============================================
VLESS+Reality 管理腳本
============================================

  1. 安裝/重新安裝 sing-box
  2. 查看節點信息
  3. 修改端口
  4. 停止服務
  5. 啟動服務
  6. 重啟服務
  7. 查看服務狀態
  8. 移除所有安裝內容
  0. 退出
============================================
```

用户输入数字选择功能。

---

### 选项 1：安装/重新安装 sing-box

执行以下步骤：

#### 步骤 1：检测系统环境
```bash
# 检测系统版本（Ubuntu/Debian/CentOS）
if [[ -f /etc/redhat-release ]]; then
    release="Centos"
elif cat /etc/issue | grep -q -E -i "debian"; then
    release="Debian"
elif cat /etc/issue | grep -q -E -i "ubuntu"; then
    release="Ubuntu"
fi

# 检测 CPU 架构
case $(uname -m) in
    aarch64) cpu="arm64";;
    x86_64) cpu="amd64";;
esac
```
- 判断当前操作系统类型
- 判断 CPU 架构（amd64 或 arm64）

#### 步骤 2：询问是否关闭防火墙
```
是否關閉防火牆？(回車默認: 是)
  1、是 (推薦)
  2、否
```
- 询问用户是否关闭防火墙
- 如果选择是，执行：
  ```bash
  systemctl stop firewalld
  systemctl disable firewalld
  ufw disable
  iptables -P INPUT ACCEPT
  iptables -P FORWARD ACCEPT
  iptables -P OUTPUT ACCEPT
  iptables -F
  ```
- 停止并禁用 firewalld、ufw
- 清空 iptables 规则

#### 步骤 3：安装系统依赖
```bash
apt update -y
apt install -y curl wget tar jq openssl coreutils
```
- 从系统官方仓库安装基础依赖
- curl/wget：网络下载
- tar：解压
- jq：JSON 处理
- openssl：加密
- coreutils：基础工具

#### 步骤 4：下载并安装 sing-box 内核
```bash
# 获取最新版本号
sbcore=$(curl -Ls https://github.com/SagerNet/sing-box/releases/latest | grep -oP 'tag/v\K[0-9.]+')

# 下载 sing-box
sbname="sing-box-$sbcore-linux-$cpu"
curl -L -o /etc/s-box/sing-box.tar.gz \
    "https://github.com/SagerNet/sing-box/releases/download/v$sbcore/$sbname.tar.gz"

# 解压安装
tar xzf /etc/s-box/sing-box.tar.gz -C /etc/s-box
mv /etc/s-box/$sbname/sing-box /etc/s-box
rm -rf /etc/s-box/sing-box.tar.gz /etc/s-box/$sbname
```
- 从 GitHub 官方获取 sing-box 最新版本
- 下载对应架构的二进制文件
- 解压并安装到 `/etc/s-box/`

#### 步骤 5：生成 Reality 密钥对和 UUID
```bash
# 生成 Reality 密钥对
key_pair=$(/etc/s-box/sing-box generate reality-keypair)
private_key=$(echo "$key_pair" | awk '/PrivateKey/ {print $2}' | tr -d '"')
public_key=$(echo "$key_pair" | awk '/PublicKey/ {print $2}' | tr -d '"')

# 生成 short_id (4位十六进制)
short_id=$(/etc/s-box/sing-box generate rand --hex 4)

# 生成 UUID
uuid=$(/etc/s-box/sing-box generate uuid)
```
- 使用 sing-box 内置命令生成私钥/公钥对
- 生成 4 位十六进制的 short_id
- 生成用户 UUID
- **注意**：所有密钥在本地生成，不外传

#### 步骤 6：设置端口
```
請輸入端口 (10000-65535)，或直接回車隨機生成:
```
- 用户输入端口号，或直接回车随机生成
- 端口范围：10000-65535

#### 步骤 7：创建配置文件
```bash
cat > /etc/s-box/sb.json <<EOF
{
  "log": { "disabled": false, "level": "info", "timestamp": true },
  "inbounds": [{
    "type": "vless",
    "tag": "vless-reality",
    "listen": "::",
    "listen_port": ${port},
    "users": [{ "uuid": "${uuid}", "flow": "xtls-rprx-vision" }],
    "tls": {
      "enabled": true,
      "server_name": "apple.com",
      "reality": {
        "enabled": true,
        "handshake": { "server": "apple.com", "server_port": 443 },
        "private_key": "$private_key",
        "short_id": ["$short_id"]
      }
    }
  }],
  "outbounds": [{ "type": "direct", "tag": "direct" }],
  "route": { "rules": [{ "type": "default", "action": "sniff" }] }
}
EOF
```
- 写入 JSON 配置文件
- 配置 VLESS+Reality 入站
- 使用 xtls-rprx-vision 流程
- Reality 伪装域名：apple.com

#### 步骤 8：创建 systemd 服务
```bash
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
```
- 创建 systemd 服务单元文件
- 设置开机自启
- 启动 sing-box 服务

#### 步骤 9：输出节点信息
- 显示 UUID、端口、SNI、公钥、Short ID、服务器 IP
- 输出完整的 VLESS 分享链接

---

### 选项 2：查看节点信息

```bash
# 读取配置文件
uuid=$(jq -r '.inbounds[0].users[0].uuid' /etc/s-box/sb.json)
port=$(jq -r '.inbounds[0].listen_port' /etc/s-box/sb.json)
sni=$(jq -r '.inbounds[0].tls.server_name' /etc/s-box/sb.json)
public_key=$(cat /etc/s-box/public.key)
short_id=$(jq -r '.inbounds[0].tls.reality.short_id[0]' /etc/s-box/sb.json)

# 获取服务器 IP
server_ip=$(curl -s4m5 icanhazip.com || curl -s6m5 icanhazip.com)

# 拼接分享链接
vl_link="vless://${uuid}@${server_ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${public_key}&sid=${short_id}&type=tcp&headerType=none#VLESS-Reality"
```
- 从配置文件读取节点参数
- 获取服务器公网 IP
- 生成 VLESS 分享链接

---

### 选项 3：修改端口

```bash
# 读取当前端口
current_port=$(jq -r '.inbounds[0].listen_port' /etc/s-box/sb.json)

# 询问新端口
echo "目前端口: $current_port"
read -p "請輸入: " new_port

# 随机生成
if [[ -z "$new_port" ]]; then
    new_port=$(shuf -i 10000-65535 -n 1)
fi

# 修改配置
jq --arg port "$new_port" '.inbounds[0].listen_port = ($port | tonumber)' /etc/s-box/sb.json > /tmp/sb.json.tmp
mv /tmp/sb.json.tmp /etc/s-box/sb.json

# 重启服务
systemctl restart sing-box
```
- 显示当前端口
- 输入新端口或回车随机生成
- 使用 jq 修改配置文件
- 重启服务生效

---

### 选项 4/5/6：停止/启动/重启服务

```bash
systemctl stop sing-box
systemctl start sing-box
systemctl restart sing-box
```

使用 systemd 管理 sing-box 服务。

---

### 选项 7：查看服务状态

```bash
systemctl status sing-box
```

显示 systemd 服务状态信息。

---

### 选项 8：移除所有安装内容

```bash
# 确认卸载
read -p "輸入 'yes' 確認刪除: " confirm
if [[ "$confirm" != "yes" ]]; then
    exit
fi

# 停止并禁用服务
systemctl stop sing-box
systemctl disable sing-box

# 删除服务文件
rm -f /etc/systemd/system/sing-box.service
systemctl daemon-reload

# 删除配置目录
rm -rf /etc/s-box
```
- 确认用户输入 `yes`
- 停止并禁用 systemd 服务
- 删除服务单元文件
- 删除所有配置和二进制文件

---

## 输出示例

安装完成后显示节点信息：

```
============================================
  UUID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  端口: 12345
  SNI: apple.com
  公鑰: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  Short ID: xxxxxxxx
  服務器IP: xxx.xxx.xxx.xxx
============================================

分享鏈接:
vless://xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx@xxx.xxx.xxx.xxx:12345?encryption=none&flow=xtls-rprx-vision&security=reality&sni=apple.com&fp=chrome&pbk=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx&sid=xxxxxxxx&type=tcp&headerType=none#VLESS-Reality
============================================
```

---

## 配置文件位置

| 文件 | 路径 |
|------|------|
| 配置文件 | `/etc/s-box/sb.json` |
| 二进制文件 | `/etc/s-box/sing-box` |
| 公钥文件 | `/etc/s-box/public.key` |
| systemd 服务 | `/etc/systemd/system/sing-box.service` |

---

## 管理命令

```bash
# 停止服务
systemctl stop sing-box

# 启动服务
systemctl start sing-box

# 重启服务
systemctl restart sing-box

# 查看状态
systemctl status sing-box

# 查看日志
journalctl -u sing-box -f
```

---

## 注意事项

- 需要 root 权限运行
- 默认关闭防火墙
- 端口范围：10000-65535
- SNI 域名：apple.com（可修改配置文件）
- 所有密钥在本地生成，不外传
