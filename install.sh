#!/bin/bash

set -e  # 使脚本在任何命令失败时退出

# 确保脚本以root用户运行
if [ "$(id -u)" -ne 0 ]; then
    echo "请以root用户运行此脚本。"
    exit 1
fi

# 定义包管理器命令
detect_package_manager() {
    if command -v apt-get &> /dev/null; then
        PM_INSTALL="apt-get install -y"
        PM_UPDATE="apt-get update"
        PM_UPGRADE="apt-get upgrade -y"
    elif command -v yum &> /dev/null; then
        PM_INSTALL="yum install -y"
        PM_UPDATE="yum update -y"
    elif command -v dnf &> /dev/null; then
        PM_INSTALL="dnf install -y"
        PM_UPDATE="dnf update -y"
    elif command -v pacman &> /dev/null; then
        PM_INSTALL="pacman -Syu --noconfirm"
        PM_UPDATE="pacman -Sy"
    else
        echo "不支持的包管理器。"
        exit 1
    fi
}

detect_package_manager
echo "p10%"

# 自动切换到CDN软件源
switch_to_cdn_sources() {
    if command -v apt-get &> /dev/null; then
        source /etc/os-release
        distro_id=$ID
        distro_codename=$(lsb_release -cs 2>/dev/null || echo "focal")

        # 备份原始 sources.list
        cp /etc/apt/sources.list /etc/apt/sources.list.bak

        # 切换到CDN软件源
        if [ "$distro_id" = "ubuntu" ]; then
            echo "deb http://archive.ubuntu.com/ubuntu/ $distro_codename main restricted universe multiverse" > /etc/apt/sources.list
            echo "deb http://archive.ubuntu.com/ubuntu/ $distro_codename-updates main restricted universe multiverse" >> /etc/apt/sources.list
            echo "deb http://archive.ubuntu.com/ubuntu/ $distro_codename-backports main restricted universe multiverse" >> /etc/apt/sources.list
            echo "deb http://security.ubuntu.com/ubuntu $distro_codename-security main restricted universe multiverse" >> /etc/apt/sources.list
        elif [ "$distro_id" = "debian" ]; then
            echo "deb http://deb.debian.org/debian/ $distro_codename main contrib non-free" > /etc/apt/sources.list
            echo "deb http://deb.debian.org/debian/ $distro_codename-updates main contrib non-free" >> /etc/apt/sources.list
            echo "deb http://deb.debian.org/debian-security $distro_codename-security main contrib non-free" >> /etc/apt/sources.list
        else
            return
        fi

        apt-get update
    fi
}

switch_to_cdn_sources
echo "p20%"

# 锁文件列表
LOCK_FILES=(
    "/var/lib/dpkg/lock"
    "/var/lib/apt/lists/lock"
    "/var/lib/dpkg/lock-frontend"
)

# 处理锁文件的函数
handle_lock_file() {
    local lock_file="$1"

    if lsof "$lock_file" &>/dev/null; then
        echo "Detected lock on $lock_file"

        # 找出占用锁文件的进程 ID
        local pid
        pid=$(lsof -t "$lock_file")

        if [ -n "$pid" ]; then
            echo "Lock is held by process $pid"

            # 检查进程是否仍在运行
            if ps -p "$pid" &>/dev/null; then
                echo "Process $pid is still running. Attempting to terminate it..."
                if kill "$pid"; then
                    echo "Successfully terminated process $pid"
                else
                    echo "Failed to terminate process $pid. You may need to check it manually."
                    exit 1
                fi
            else
                echo "Process $pid is no longer running."
            fi
        fi

        # 删除锁文件
        if rm -f "$lock_file"; then
            echo "Removed lock file $lock_file"
        else
            echo "Failed to remove lock file $lock_file. You may need to check it manually."
            exit 1
        fi
    else
        echo "No lock on $lock_file"
    fi
}

# 检查是否需要运行 dpkg --configure -a
check_and_configure_dpkg() {
    # 遍历并处理每个锁文件
    for lock_file in "${LOCK_FILES[@]}"; do
        handle_lock_file "$lock_file"
    done
    if dpkg --audit 2>/dev/null | grep -q "未配置"; then
        echo "检测到未配置的包，正在重新配置 dpkg..."
        if dpkg --configure -a; then
            echo "dpkg 重新配置成功。"
        else
            echo "dpkg 重新配置失败。请检查错误。"
            exit 1
        fi
    else
        echo "没有未配置的包。"
    fi
}

check_and_configure_dpkg || { echo "安装失败 => 请重试或者联系客服"; exit 1; }

# 更新包索引并安装必要的包
$PM_UPDATE && $PM_INSTALL curl ca-certificates unzip jq gpg lsb-release || { echo "安装失败 => 更新包索引并安装必要的包失败"; exit 1; }

echo "p30%"

# 安装 Docker 和 Docker Compose
install_docker() {
    local arch
    arch=$(dpkg --print-architecture)

    if command -v apt-get &> /dev/null; then
        apt-get install -y gnupg apt-transport-https ca-certificates software-properties-common

        # 获取发行版 ID 和版本代号
        source /etc/os-release
        distro_id=$ID
        distro_codename=$(lsb_release -cs)

        # 根据发行版设置 GPG 公钥 URL 和 APT 源 URL
        if [ "$distro_id" = "ubuntu" ]; then
           gpg_urls=("https://download.docker.com/linux/ubuntu/gpg" "https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg")
           repo_urls=("https://download.docker.com/linux/ubuntu" "https://mirrors.aliyun.com/docker-ce/linux/ubuntu")
        elif [ "$distro_id" = "debian" ]; then
           gpg_urls=("https://download.docker.com/linux/debian/gpg" "https://mirrors.aliyun.com/docker-ce/linux/debian/gpg")
           repo_urls=("https://download.docker.com/linux/debian" "https://mirrors.aliyun.com/docker-ce/linux/debian")
        else
           echo "Unsupported distribution: $distro_id"
           exit 1
        fi

        # 尝试下载并添加 Docker 的 GPG 公钥
        for i in "${!gpg_urls[@]}"; do
          gpg_url="${gpg_urls[i]}"
          repo_url="${repo_urls[i]}"
          if curl -fsSL "$gpg_url" | gpg --dearmor --batch --yes -o /usr/share/keyrings/docker-archive-keyring.gpg; then
             echo "Successfully added GPG key from $gpg_url"
             echo "deb [arch=$arch signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] $repo_url $distro_codename stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
             break
          else
             echo "Failed to add GPG key from $gpg_url, trying next..."
          fi
        done

        apt-get update
        $PM_INSTALL docker-ce docker-compose-plugin
    elif command -v yum &> /dev/null || command -v dnf &> /dev/null; then
        $PM_INSTALL dnf-plugins-core
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        $PM_INSTALL docker-ce docker-compose-plugin
    elif command -v pacman &> /dev/null; then
        $PM_INSTALL docker docker-compose
    fi

    systemctl start docker
    systemctl enable docker

    docker --version
    docker compose --version
}

install_docker || { echo "安装失败 => Docker 安装失败"; exit 1; }

echo "p60%"

# 下载并解压ZIP文件
download_and_extract_zip() {
    # 这里需要替换为你的实际OSS下载地址
    local zip_url="https://your-oss-bucket.oss-region.aliyuncs.com/aigc-platform.zip"
    local dest_dir="/opt/aigc-platform"

    if [ ! -d "$dest_dir" ]; then
        mkdir -p "$dest_dir"
        echo "Created directory: $dest_dir"
    fi

    echo "正在下载项目文件..."
    curl -L "$zip_url" -o /tmp/aigc-platform.zip
    unzip -o /tmp/aigc-platform.zip -d "$dest_dir"
}

download_and_extract_zip || { echo "安装失败 => 下载或解压失败"; exit 1; }
echo "p70%"

# 生成随机配置
generate_config() {
    local config_dir="/opt/aigc-platform/config"
    mkdir -p "$config_dir"
    
    # 生成随机字符串
    admin_entrypoint=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 16)
    admin_username="admin"
    admin_password=$(tr -dc 'a-zA-Z0-9!@#$%^&*' < /dev/urandom | head -c 16)
    db_password=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 20)
    jwt_secret=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 32)
    
    # 创建配置文件
    cat > "$config_dir/install.json" << EOF
{
  "adminEntrypoint": "$admin_entrypoint",
  "adminUsername": "$admin_username",
  "adminPassword": "$admin_password",
  "dbPassword": "$db_password",
  "jwtSecret": "$jwt_secret",
  "installTime": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

    # 创建环境变量文件
    cat > "/opt/aigc-platform/.env" << EOF
# Database Configuration
DB_HOST=mongo
DB_PORT=27017
DB_DATABASE=aigc
DB_USER=aigc
DB_PASS=$db_password

# Application Configuration
NODE_ENV=production
PORT=3000
JWT_SECRET=$jwt_secret

# Admin Configuration
ADMIN_USERNAME=$admin_username
ADMIN_PASSWORD=$admin_password
ADMIN_ENTRYPOINT=$admin_entrypoint
EOF

    echo "配置文件已生成"
}

generate_config

# 初始化MongoDB
init_mongodb() {
    local config_dir="/opt/aigc-platform/config"
    local db_password=$(jq -r '.dbPassword' "$config_dir/install.json")
    
    # 创建MongoDB初始化脚本
    cat > "$config_dir/init-mongo.js" << EOF
db = db.getSiblingDB('aigc');

db.createUser({
  user: 'aigc',
  pwd: '$db_password',
  roles: [
    {
      role: 'readWrite',
      db: 'aigc'
    }
  ]
});

// 创建管理员用户
db.users.insertOne({
  username: 'admin',
  password: '\$2a\$10\$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi',
  role: 'admin',
  createdAt: new Date(),
  isActive: true
});

// 创建模板集合
db.templates.createIndex({ "name": 1 }, { unique: true });

print('Database initialized successfully');
EOF
}

init_mongodb

# 创建更新脚本
cat << 'EOF' > /usr/local/bin/update_aigc_platform.sh
#!/bin/bash

# 创建更新函数
update_aigc_application() {
    cd /opt/aigc-platform || exit 1
    docker compose -f docker-compose.prod.yml pull
    docker compose -f docker-compose.prod.yml up -d
    echo "应用已更新."
}

# 创建 FIFO 管道
update_fifo="/tmp/update_aigc_platform"
if [[ ! -p "$update_fifo" ]]; then
    mkfifo "$update_fifo"
fi

# 在后台运行一个循环，监听更新请求
while true; do
    if read < "$update_fifo"; then
        update_aigc_application
    fi
done
EOF

# 确保更新脚本有执行权限
chmod +x /usr/local/bin/update_aigc_platform.sh

# 创建 systemd 服务文件
cat << 'EOF' > /etc/systemd/system/update_aigc_platform.service
[Unit]
Description=Update AIGC Platform Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/update_aigc_platform.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 systemd 管理器配置
systemctl daemon-reload

# 启动服务
systemctl start update_aigc_platform.service

# 设置服务开机自启
systemctl enable update_aigc_platform.service

echo "更新服务已配置并启动。"

# 启动 Docker Compose 服务
cd /opt/aigc-platform || exit 1
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d

echo "初始化中, 请稍等几分钟..."
sleep 0.1
echo "p90%"
sleep 30

# 清理临时文件
rm -f /tmp/aigc-platform.zip

# 检查 config/install.json 是否存在
check_json_file() {
    local json_file="config/install.json"
    local max_attempts=6
    local attempt=0

    while [ ! -f "$json_file" ]; do
        if [ "$attempt" -ge "$max_attempts" ]; then
            echo "初始化可能失败，请点查询信息或安装重试或联系客服"
            exit 1
        fi
        echo "安装成功，正在等待程序初始化，请稍等..."
        sleep 10
        attempt=$((attempt + 1))
    done
}

check_json_file || { echo "安装失败 => 初始化慢或者失败，请查询或者联系客服"; exit 1; }

# 读取JSON文件
json_file="config/install.json"

# 提取配置信息
admin_entrypoint=$(jq -r '.adminEntrypoint' "$json_file")
admin_username=$(jq -r '.adminUsername' "$json_file")
admin_password=$(jq -r '.adminPassword' "$json_file")
public_ip=$(curl -s ipv4.ip.sb)
echo "p95%"
sleep 0.1

echo "后台地址: http://$public_ip/$admin_entrypoint"
sleep 0.1
echo "管理员账号: $admin_username"
sleep 0.1
echo "管理员密码: $admin_password"
sleep 0.1
echo "请保存当前管理员账号密码"
sleep 0.1
echo "p100%"