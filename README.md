# VLESS+Reality 一键安装脚本

一个简洁的 VLESS+Reality 协议安装管理脚本，基于 sing-box 内核。

## 功能

- ✅ 一键安装 VLESS+Reality
- ✅ 自定义端口
- ✅ 查看节点信息
- ✅ 管理服务（启动/停止/重启）
- ✅ 卸载功能
- ✅ 支持 Ubuntu/Debian/CentOS
- ✅ 支持 amd64/arm64 架构

## 安装

```bash
# 方式一：直接运行（推荐）
bash <(wget -qO- https://raw.githubusercontent.com/jonas678/sing-box-self/main/vless-reality.sh)

# 方式二：下载后运行
curl -o /tmp/vless.sh https://raw.githubusercontent.com/jonas678/sing-box-self/main/vless-reality.sh && bash /tmp/vless.sh
```

## 使用方法

运行脚本后显示菜单：

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

输入数字选择对应功能。

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

## 配置文件位置

- 配置文件：`/etc/s-box/sb.json`
- 二进制文件：`/etc/s-box/sing-box`

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
```

## 注意事项

- 需要 root 权限运行
- 默认关闭防火墙
- 端口范围：10000-65535
- SNI 域名：apple.com（可修改配置文件）
