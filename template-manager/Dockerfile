FROM node:18-alpine

# 安装必要工具
RUN apk add --no-cache \
    curl \
    unzip \
    git \
    && rm -rf /var/cache/apk/*

# 创建应用用户
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup

# 设置工作目录
WORKDIR /app

# 复制模板管理器文件
COPY package*.json ./
COPY src/ ./src/

# 安装依赖
RUN npm install --only=production && \
    npm cache clean --force

# 创建必要目录
RUN mkdir -p templates admin logs && \
    chown -R appuser:appgroup /app

# 切换到应用用户
USER appuser

# 暴露端口
EXPOSE 4000

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:4000/health || exit 1

# 启动服务
CMD ["node", "src/server.js"]