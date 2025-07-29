const express = require('express');
const fs = require('fs-extra');
const path = require('path');
const { exec } = require('child_process');
const archiver = require('archiver');
const unzipper = require('unzipper');
const axios = require('axios');

const app = express();
const PORT = process.env.PORT || 4000;

// 中间件
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// 路径配置
const TEMPLATES_DIR = '/app/templates';
const ADMIN_DIR = '/app/admin';
const SCRIPTS_DIR = '/app/scripts';

// 确保目录存在
fs.ensureDirSync(TEMPLATES_DIR);
fs.ensureDirSync(ADMIN_DIR);

/**
 * 下载并安装模板
 */
app.post('/api/templates/install', async (req, res) => {
    try {
        const { templateId, templateUrl, templateName } = req.body;
        
        if (!templateId || !templateUrl) {
            return res.status(400).json({ error: '模板ID和下载地址不能为空' });
        }
        
        const templateDir = path.join(TEMPLATES_DIR, templateId);
        
        // 检查模板是否已存在
        if (await fs.pathExists(templateDir)) {
            return res.status(409).json({ error: '模板已存在' });
        }
        
        // 下载模板文件
        console.log(`开始下载模板: ${templateUrl}`);
        const response = await axios({
            method: 'GET',
            url: templateUrl,
            responseType: 'stream'
        });
        
        // 创建临时文件
        const tempFile = path.join('/tmp', `${templateId}.zip`);
        const writer = fs.createWriteStream(tempFile);
        
        response.data.pipe(writer);
        
        await new Promise((resolve, reject) => {
            writer.on('finish', resolve);
            writer.on('error', reject);
        });
        
        // 解压模板
        console.log(`开始解压模板: ${templateId}`);
        await fs.ensureDir(templateDir);
        
        await new Promise((resolve, reject) => {
            fs.createReadStream(tempFile)
                .pipe(unzipper.Extract({ path: templateDir }))
                .on('close', resolve)
                .on('error', reject);
        });
        
        // 清理临时文件
        await fs.remove(tempFile);
        
        // 验证模板结构
        const indexPath = path.join(templateDir, 'index.html');
        if (!await fs.pathExists(indexPath)) {
            await fs.remove(templateDir);
            return res.status(400).json({ error: '模板格式无效，缺少index.html文件' });
        }
        
        console.log(`模板安装成功: ${templateId}`);
        res.json({ 
            message: '模板安装成功',
            templateId,
            templateName,
            path: templateDir
        });
        
    } catch (error) {
        console.error('安装模板失败:', error);
        res.status(500).json({ error: '安装模板失败: ' + error.message });
    }
});

/**
 * 卸载模板
 */
app.delete('/api/templates/:templateId', async (req, res) => {
    try {
        const { templateId } = req.params;
        const templateDir = path.join(TEMPLATES_DIR, templateId);
        
        if (!await fs.pathExists(templateDir)) {
            return res.status(404).json({ error: '模板不存在' });
        }
        
        // 删除模板目录
        await fs.remove(templateDir);
        
        console.log(`模板卸载成功: ${templateId}`);
        res.json({ message: '模板卸载成功', templateId });
        
    } catch (error) {
        console.error('卸载模板失败:', error);
        res.status(500).json({ error: '卸载模板失败: ' + error.message });
    }
});

/**
 * 获取已安装的模板列表
 */
app.get('/api/templates', async (req, res) => {
    try {
        const templates = [];
        const templateDirs = await fs.readdir(TEMPLATES_DIR);
        
        for (const templateId of templateDirs) {
            const templateDir = path.join(TEMPLATES_DIR, templateId);
            const stat = await fs.stat(templateDir);
            
            if (stat.isDirectory()) {
                const indexPath = path.join(templateDir, 'index.html');
                const configPath = path.join(templateDir, 'template.json');
                
                let templateInfo = {
                    id: templateId,
                    name: templateId,
                    installed: await fs.pathExists(indexPath),
                    installedAt: stat.mtime
                };
                
                // 读取模板配置信息
                if (await fs.pathExists(configPath)) {
                    try {
                        const config = await fs.readJson(configPath);
                        templateInfo = { ...templateInfo, ...config };
                    } catch (e) {
                        console.warn(`读取模板配置失败: ${templateId}`, e);
                    }
                }
                
                templates.push(templateInfo);
            }
        }
        
        res.json({ templates });
        
    } catch (error) {
        console.error('获取模板列表失败:', error);
        res.status(500).json({ error: '获取模板列表失败: ' + error.message });
    }
});

/**
 * 配置域名
 */
app.post('/api/domains/configure', async (req, res) => {
    try {
        const { domain, templateId, suffix, httpsEnabled = false } = req.body;
        
        if (!domain || !templateId) {
            return res.status(400).json({ error: '域名和模板ID不能为空' });
        }
        
        const templateDir = path.join(TEMPLATES_DIR, templateId);
        if (!await fs.pathExists(templateDir)) {
            return res.status(404).json({ error: '模板不存在' });
        }
        
        // 调用域名配置脚本
        const scriptPath = path.join(SCRIPTS_DIR, 'generate-domain-config.js');
        const command = `node "${scriptPath}" generate "${domain}" "${templateId}" "${suffix || ''}" "${httpsEnabled}"`;
        
        await new Promise((resolve, reject) => {
            exec(command, (error, stdout, stderr) => {
                if (error) {
                    console.error('配置域名失败:', error);
                    reject(error);
                } else {
                    console.log('域名配置成功:', stdout);
                    resolve();
                }
            });
        });
        
        res.json({ 
            message: '域名配置成功',
            domain,
            templateId,
            suffix,
            httpsEnabled
        });
        
    } catch (error) {
        console.error('配置域名失败:', error);
        res.status(500).json({ error: '配置域名失败: ' + error.message });
    }
});

/**
 * 删除域名配置
 */
app.delete('/api/domains/:domain', async (req, res) => {
    try {
        const { domain } = req.params;
        
        // 调用域名删除脚本
        const scriptPath = path.join(SCRIPTS_DIR, 'generate-domain-config.js');
        const command = `node "${scriptPath}" remove "${domain}"`;
        
        await new Promise((resolve, reject) => {
            exec(command, (error, stdout, stderr) => {
                if (error) {
                    console.error('删除域名配置失败:', error);
                    reject(error);
                } else {
                    console.log('域名配置删除成功:', stdout);
                    resolve();
                }
            });
        });
        
        res.json({ message: '域名配置删除成功', domain });
        
    } catch (error) {
        console.error('删除域名配置失败:', error);
        res.status(500).json({ error: '删除域名配置失败: ' + error.message });
    }
});

/**
 * 健康检查
 */
app.get('/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

/**
 * 备份模板
 */
app.post('/api/templates/:templateId/backup', async (req, res) => {
    try {
        const { templateId } = req.params;
        const templateDir = path.join(TEMPLATES_DIR, templateId);
        
        if (!await fs.pathExists(templateDir)) {
            return res.status(404).json({ error: '模板不存在' });
        }
        
        const backupPath = path.join('/tmp', `${templateId}-backup-${Date.now()}.zip`);
        const output = fs.createWriteStream(backupPath);
        const archive = archiver('zip', { zlib: { level: 9 } });
        
        archive.pipe(output);
        archive.directory(templateDir, false);
        await archive.finalize();
        
        res.download(backupPath, `${templateId}-backup.zip`, (err) => {
            if (err) {
                console.error('下载备份文件失败:', err);
            }
            // 清理临时文件
            fs.remove(backupPath).catch(console.error);
        });
        
    } catch (error) {
        console.error('备份模板失败:', error);
        res.status(500).json({ error: '备份模板失败: ' + error.message });
    }
});

// 错误处理中间件
app.use((error, req, res, next) => {
    console.error('服务器错误:', error);
    res.status(500).json({ error: '内部服务器错误' });
});

// 启动服务器
app.listen(PORT, () => {
    console.log(`模板管理服务启动在端口 ${PORT}`);
});