#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

/**
 * 生成域名配置文件
 * @param {Object} options 配置选项
 * @param {string} options.domain 域名
 * @param {string} options.suffix 域名后缀（可选）
 * @param {string} options.templateId 模板ID
 * @param {boolean} options.httpsEnabled 是否启用HTTPS
 */
function generateDomainConfig(options) {
    const { domain, suffix, templateId, httpsEnabled = false } = options;
    
    // 读取模板文件
    const templatePath = path.join(__dirname, '../nginx/conf.d/template.conf.template');
    const template = fs.readFileSync(templatePath, 'utf8');
    
    // 生成后缀位置块
    let suffixLocationBlock = '';
    let rootLocationBlock = '';
    
    if (suffix) {
        // 有后缀时，只允许通过 domain.com/suffix 访问
        suffixLocationBlock = `
    location /${suffix}/ {
        alias /usr/share/nginx/html/templates/${templateId}/;
        try_files $uri $uri/ /index.html;
        
        # 禁用缓存（对于HTML文件）
        location ~* \\.html$ {
            add_header Cache-Control "no-cache, no-store, must-revalidate";
            add_header Pragma "no-cache";
            add_header Expires "0";
        }
    }
    
    location = /${suffix} {
        return 301 /${suffix}/;
    }`;
        
        // 根路径返回404或重定向
        rootLocationBlock = `
    location = / {
        return 404;
    }
    
    location / {
        return 404;
    }`;
    } else {
        // 没有后缀时，直接从根路径访问
        rootLocationBlock = `
    location / {
        root /usr/share/nginx/html/templates/${templateId};
        try_files $uri $uri/ /index.html;
        
        # 禁用缓存（对于HTML文件）
        location ~* \\.html$ {
            add_header Cache-Control "no-cache, no-store, must-revalidate";
            add_header Pragma "no-cache";
            add_header Expires "0";
        }
    }`;
    }
    
    // 生成HTTPS配置块
    let httpsServerBlock = '';
    if (httpsEnabled) {
        httpsServerBlock = `
server {
    listen 443 ssl http2;
    server_name ${domain};
    
    ssl_certificate /etc/nginx/ssl/${domain}.crt;
    ssl_certificate_key /etc/nginx/ssl/${domain}.key;
    
    # SSL配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # 安全头
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    ${suffix ? suffixLocationBlock : rootLocationBlock}
    
    # 静态资源处理
    location ~* \\.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        root /usr/share/nginx/html/templates/${templateId};
        expires 1y;
        add_header Cache-Control "public, immutable";
        try_files $uri =404;
    }
    
    # API代理
    location /api/ {
        proxy_pass http://backend:3000/api/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Template-ID ${templateId};
        proxy_set_header X-Domain-Suffix ${suffix || ''};
    }
}`;
    }
    
    // 替换模板变量
    const config = template
        .replace(/\${DOMAIN_NAME}/g, domain)
        .replace(/\${TEMPLATE_ID}/g, templateId)
        .replace(/\${DOMAIN_SUFFIX}/g, suffix || '')
        .replace(/\${SUFFIX_LOCATION_BLOCK}/g, suffixLocationBlock)
        .replace(/\${ROOT_LOCATION_BLOCK}/g, rootLocationBlock)
        .replace(/\${HTTPS_SERVER_BLOCK}/g, httpsServerBlock);
    
    // 写入配置文件
    const configPath = path.join(__dirname, '../nginx/conf.d', `${domain}.conf`);
    fs.writeFileSync(configPath, config);
    
    console.log(`Domain configuration generated: ${configPath}`);
    return configPath;
}

/**
 * 删除域名配置文件
 * @param {string} domain 域名
 */
function removeDomainConfig(domain) {
    const configPath = path.join(__dirname, '../nginx/conf.d', `${domain}.conf`);
    if (fs.existsSync(configPath)) {
        fs.unlinkSync(configPath);
        console.log(`Domain configuration removed: ${configPath}`);
    }
}

/**
 * 重新加载Nginx配置
 */
function reloadNginx() {
    const { exec } = require('child_process');
    
    exec('docker exec aigc_nginx nginx -t && docker exec aigc_nginx nginx -s reload', (error, stdout, stderr) => {
        if (error) {
            console.error(`Nginx reload failed: ${error}`);
            return;
        }
        console.log('Nginx configuration reloaded successfully');
    });
}

// 命令行接口
if (require.main === module) {
    const args = process.argv.slice(2);
    const command = args[0];
    
    switch (command) {
        case 'generate':
            const domain = args[1];
            const templateId = args[2];
            const suffix = args[3] || '';
            const httpsEnabled = args[4] === 'true';
            
            if (!domain || !templateId) {
                console.error('Usage: node generate-domain-config.js generate <domain> <templateId> [suffix] [httpsEnabled]');
                process.exit(1);
            }
            
            generateDomainConfig({ domain, templateId, suffix, httpsEnabled });
            reloadNginx();
            break;
            
        case 'remove':
            const domainToRemove = args[1];
            if (!domainToRemove) {
                console.error('Usage: node generate-domain-config.js remove <domain>');
                process.exit(1);
            }
            
            removeDomainConfig(domainToRemove);
            reloadNginx();
            break;
            
        default:
            console.error('Usage: node generate-domain-config.js <generate|remove> ...');
            process.exit(1);
    }
}

module.exports = {
    generateDomainConfig,
    removeDomainConfig,
    reloadNginx
};