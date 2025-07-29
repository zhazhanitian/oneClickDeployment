#!/bin/bash

set -e

# 检查是否以root用户运行
if [ "$(id -u)" -ne 0 ]; then
    echo "请以root用户运行此脚本。"
    exit 1
fi

# 检查安装目录是否存在
INSTALL_DIR="/opt/aigc-platform"
CONFIG_FILE="$INSTALL_DIR/config/install.json"

if [ ! -d "$INSTALL_DIR" ]; then
    echo "错误: 未找到安装目录，请先运行安装脚本。"
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "错误: 未找到配置文件，安装可能未完成。"
    exit 1
fi

# 检查服务状态
echo "=== 服务状态检查 ==="
cd "$INSTALL_DIR"

if command -v docker &> /dev/null && command -v docker-compose &> /dev/null; then
    echo "Docker 服务状态:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep aigc || echo "未找到相关容器"
    echo ""
fi

# 读取配置信息
if command -v jq &> /dev/null; then
    echo "=== 访问信息 ==="
    
    admin_entrypoint=$(jq -r '.adminEntrypoint' "$CONFIG_FILE")
    admin_username=$(jq -r '.adminUsername' "$CONFIG_FILE")
    admin_password=$(jq -r '.adminPassword' "$CONFIG_FILE")
    install_time=$(jq -r '.installTime' "$CONFIG_FILE")
    
    # 获取公网IP
    public_ip=$(curl -s --connect-timeout 5 ipv4.ip.sb || echo "无法获取公网IP")
    
    echo "安装时间: $install_time"
    echo "后台地址: http://$public_ip/$admin_entrypoint"
    echo "管理员账号: $admin_username"
    echo "管理员密码: $admin_password"
    echo ""
    
    echo "=== 使用说明 ==="
    echo "1. 访问管理后台地址进行登录"
    echo "2. 在模板管理中选择并安装需要的模板"
    echo "3. 在域名管理中配置你的域名和模板"
    echo "4. 确保域名已解析到服务器IP: $public_ip"
    echo ""
else
    echo "警告: 未安装jq，无法解析配置文件"
    echo "配置文件位置: $CONFIG_FILE"
fi

echo "=== 系统信息 ==="
echo "安装目录: $INSTALL_DIR"
echo "系统版本: $(uname -a)"
echo "磁盘使用情况:"
df -h | head -n 1
df -h | grep -E "(/$|/opt)" || df -h / 

echo ""
echo "=== 日志查看命令 ==="
echo "查看所有服务日志: cd $INSTALL_DIR && docker-compose logs"
echo "查看后端服务日志: cd $INSTALL_DIR && docker-compose logs backend"
echo "查看Nginx日志: cd $INSTALL_DIR && docker-compose logs nginx"

echo ""
echo "如需技术支持，请保存以上信息并联系客服。"