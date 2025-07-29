# AIGC平台一键部署系统

这是一个完整的一键部署解决方案，可以快速在服务器上部署模板管理平台，支持多模板管理和动态域名配置。

## 功能特性

- 🚀 一键安装部署
- 🎨 多模板管理系统  
- 🌐 动态域名配置
- 🔒 安全的管理后台
- 📦 容器化部署
- 🔄 自动更新机制
- 📊 健康检查监控

## 系统架构

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Nginx反向代理   │────│   Express后端     │────│   MongoDB数据库  │
│   (域名路由)     │    │   (API服务)      │    │   (数据存储)    │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         │              ┌──────────────────┐              │
         └──────────────│  模板管理服务     │──────────────┘
                       │  (模板安装/配置)  │
                       └──────────────────┘
```

## 目录结构

```
/
├── install.sh                    # 一键安装脚本
├── query.sh                      # 查询脚本
├── docker-compose.prod.yml       # 生产环境配置
├── .env.template                 # 环境变量模板
├── backend/                      # 后端代码
│   ├── Dockerfile.prod           # 生产环境镜像
│   └── ...                       # 其他后端文件
├── admin/                        # 管理后台静态文件
├── nginx/                        # Nginx配置
│   ├── nginx.conf                # 主配置文件
│   └── conf.d/                   # 域名配置目录
├── config/                       # 配置文件目录
├── scripts/                      # 脚本文件
├── templates/                    # 模板存储目录
└── logs/                         # 日志目录
```

## 部署流程

### 1. 服务器准备

确保服务器满足以下要求：
- Linux系统 (Ubuntu 18.04+/CentOS 7+/Debian 9+)
- 至少2GB内存
- 至少20GB可用磁盘空间
- Root权限

### 2. 一键安装

```bash
# 下载并执行安装脚本
curl https://your-oss-domain.com/install.sh -o install.sh && chmod +x install.sh && sudo ./install.sh
```

### 3. 查询安装信息

```bash
# 查询访问地址和账号密码
curl https://your-oss-domain.com/query.sh -o query.sh && chmod +x query.sh && sudo ./query.sh
```

## 使用说明

### 管理后台功能

1. **登录管理后台**
   - 访问脚本提供的管理后台地址
   - 使用生成的账号密码登录

2. **模板管理**
   - 上传或下载模板文件
   - 安装/卸载模板
   - 查看模板列表

3. **域名配置**
   - 添加自定义域名
   - 选择对应的模板
   - 配置域名后缀（可选）
   - 启用HTTPS（如有证书）

4. **系统监控**
   - 查看系统状态
   - 监控资源使用
   - 查看访问日志

### 域名配置示例

#### 无后缀配置
- 域名：`example.com`
- 模板：`template1`
- 访问：`https://example.com/`

#### 有后缀配置
- 域名：`example.com`
- 后缀：`app`
- 模板：`template1`
- 访问：`https://example.com/app/`

## API接口

### 模板管理API

```http
# 安装模板
POST /api/templates/install
{
  "templateId": "template1",
  "templateUrl": "https://example.com/template.zip",
  "templateName": "示例模板"
}

# 获取模板列表
GET /api/templates

# 卸载模板
DELETE /api/templates/{templateId}
```

### 域名配置API

```http
# 配置域名
POST /api/domains/configure
{
  "domain": "example.com",
  "templateId": "template1",
  "suffix": "app",
  "httpsEnabled": true
}

# 删除域名配置
DELETE /api/domains/{domain}
```

## 模板格式规范

### 基本结构
```
template/
├── index.html          # 入口文件（必需）
├── template.json       # 模板配置（可选）
├── assets/            # 静态资源
├── css/               # 样式文件
├── js/                # JavaScript文件
└── images/            # 图片文件
```

### template.json配置示例
```json
{
  "name": "示例模板",
  "version": "1.0.0",
  "description": "这是一个示例模板",
  "author": "作者名称",
  "screenshot": "screenshot.png",
  "category": "business",
  "tags": ["响应式", "现代"],
  "requirements": {
    "node": ">=14.0.0"
  }
}
```

## 系统维护

### 日志查看
```bash
# 查看所有服务日志
cd /opt/aigc-platform && docker-compose logs

# 查看特定服务日志
docker-compose logs backend
docker-compose logs nginx
```

### 服务重启
```bash
cd /opt/aigc-platform
docker-compose restart

# 重启特定服务
docker-compose restart backend
```

### 备份数据
```bash
# 备份数据库
docker exec aigc_mongo mongodump --authenticationDatabase admin -u root -p password --out /backup

# 备份模板文件
tar -czf templates-backup.tar.gz /opt/aigc-platform/templates
```

### 更新系统
```bash
# 拉取最新镜像并重启
cd /opt/aigc-platform
docker-compose pull
docker-compose up -d
```

## 故障排除

### 常见问题

1. **服务启动失败**
   - 检查端口是否被占用
   - 查看Docker服务状态
   - 检查磁盘空间

2. **域名无法访问**
   - 确认域名DNS解析
   - 检查防火墙设置
   - 验证Nginx配置

3. **模板安装失败**
   - 检查模板文件格式
   - 确认网络连接
   - 查看磁盘空间

### 获取帮助

- 查看日志文件：`/opt/aigc-platform/logs/`
- 运行诊断脚本：`sudo ./query.sh`
- 联系技术支持

## 安全建议

1. **定期更新系统**
   ```bash
   # 更新系统包
   apt update && apt upgrade -y
   
   # 更新Docker镜像
   docker-compose pull && docker-compose up -d
   ```

2. **备份重要数据**
   - 定期备份数据库
   - 备份模板文件
   - 备份配置文件

3. **监控系统状态**
   - 设置磁盘空间监控
   - 监控服务运行状态
   - 查看访问日志

4. **网络安全**
   - 配置防火墙规则
   - 使用HTTPS证书
   - 定期更新密码

## 许可证

MIT License

## 更新日志

### v1.0.0
- 初始版本发布
- 支持一键安装部署
- 模板管理功能
- 动态域名配置
- 容器化部署