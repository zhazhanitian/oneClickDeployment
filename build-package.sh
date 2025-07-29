#!/bin/bash

set -e

# 项目信息
PROJECT_NAME="aigc-platform"
VERSION="1.0.0"
BUILD_DIR="build"
PACKAGE_NAME="${PROJECT_NAME}-${VERSION}.zip"

echo "开始构建 ${PROJECT_NAME} v${VERSION}"

# 清理构建目录
rm -rf ${BUILD_DIR}
mkdir -p ${BUILD_DIR}/${PROJECT_NAME}

# 复制必要文件
echo "复制项目文件..."

# 复制脚本文件
cp install.sh ${BUILD_DIR}/${PROJECT_NAME}/
cp query.sh ${BUILD_DIR}/${PROJECT_NAME}/
cp docker-compose.prod.yml ${BUILD_DIR}/${PROJECT_NAME}/docker-compose.yml
cp .env.template ${BUILD_DIR}/${PROJECT_NAME}/
cp README.md ${BUILD_DIR}/${PROJECT_NAME}/

# 复制配置文件
mkdir -p ${BUILD_DIR}/${PROJECT_NAME}/config
cp config/redis.conf ${BUILD_DIR}/${PROJECT_NAME}/config/

# 复制脚本目录
mkdir -p ${BUILD_DIR}/${PROJECT_NAME}/scripts
cp scripts/generate-domain-config.js ${BUILD_DIR}/${PROJECT_NAME}/scripts/

# 复制后端代码
echo "复制后端代码..."
cp -r backend ${BUILD_DIR}/${PROJECT_NAME}/

# 复制管理后台代码
echo "复制管理后台..."
cp -r admin ${BUILD_DIR}/${PROJECT_NAME}/

# 复制Nginx配置
echo "复制Nginx配置..."
cp -r nginx ${BUILD_DIR}/${PROJECT_NAME}/

# 复制模板管理服务
echo "复制模板管理服务..."
cp -r template-manager ${BUILD_DIR}/${PROJECT_NAME}/

# 创建必要的目录
mkdir -p ${BUILD_DIR}/${PROJECT_NAME}/templates
mkdir -p ${BUILD_DIR}/${PROJECT_NAME}/logs
mkdir -p ${BUILD_DIR}/${PROJECT_NAME}/uploads
mkdir -p ${BUILD_DIR}/${PROJECT_NAME}/ssl

# 创建目录说明文件
cat > ${BUILD_DIR}/${PROJECT_NAME}/templates/README.md << EOF
# 模板目录

此目录用于存储用户端模板文件。

每个模板应该包含：
- index.html (必需)
- template.json (可选，包含模板元信息)
- 其他静态资源文件

模板目录结构示例：
\`\`\`
templates/
├── template1/
│   ├── index.html
│   ├── template.json
│   ├── assets/
│   └── css/
└── template2/
    ├── index.html
    └── js/
\`\`\`
EOF

cat > ${BUILD_DIR}/${PROJECT_NAME}/ssl/README.md << EOF
# SSL证书目录

此目录用于存储SSL证书文件。

支持的证书格式：
- .crt 证书文件
- .key 私钥文件
- .pem PEM格式证书

文件命名规范：
- 域名.crt (如: example.com.crt)
- 域名.key (如: example.com.key)
EOF

# 设置权限
echo "设置文件权限..."
chmod +x ${BUILD_DIR}/${PROJECT_NAME}/install.sh
chmod +x ${BUILD_DIR}/${PROJECT_NAME}/query.sh
chmod +x ${BUILD_DIR}/${PROJECT_NAME}/scripts/generate-domain-config.js

# 创建压缩包
echo "创建压缩包..."
cd ${BUILD_DIR}
zip -r ${PACKAGE_NAME} ${PROJECT_NAME}/

# 显示结果
echo "构建完成！"
echo "包大小: $(du -h ${PACKAGE_NAME} | cut -f1)"
echo "输出文件: ${BUILD_DIR}/${PACKAGE_NAME}"

# 生成SHA256校验值
sha256sum ${PACKAGE_NAME} > ${PACKAGE_NAME}.sha256
echo "SHA256校验文件: ${BUILD_DIR}/${PACKAGE_NAME}.sha256"

echo ""
echo "部署说明："
echo "1. 将 ${PACKAGE_NAME} 上传到OSS或CDN"
echo "2. 修改 install.sh 中的下载地址"
echo "3. 提供用户下载安装脚本"

echo ""
echo "安装命令示例："
echo "curl https://your-domain.com/install.sh -o install.sh && chmod +x install.sh && sudo ./install.sh"