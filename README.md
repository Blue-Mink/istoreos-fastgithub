# iStoreOS FastGitHub Docker 部署

在 **iStoreOS** 旁路由上通过 Docker 部署 **FastGitHub**，加速从 GitHub 的访问（git clone、下载 release 等）。

## 功能

- 🚀 加速 GitHub Release 下载（速度提升 3-5 倍）
- 🐳 基于 Docker 部署，不影响旁路由系统本身
- 🔄 容器自动重启，系统重启后自动恢复
- 🌐 支持 HTTP 代理模式，其他容器或设备均可使用

## 环境要求

- 系统：iStoreOS 24.10.x（OpenWrt 变体）
- 架构：x86_64 / aarch64
- 已安装 Docker 和 dockerd 服务
- 至少 1GB 可用磁盘空间

## 快速部署

### 1. 拉取并运行容器

```bash
docker run -d \
  --name fastgithub \
  --restart always \
  --network host \
  slcnx/fastgithub:latest
```

### 2. 验证部署

```bash
# 检查容器状态
docker ps --filter name=fastgithub

# 检查监听端口
netstat -tlnp | grep fastgithub
```

正常输出应显示：
- `127.0.0.1:38443` - HTTPS 代理端口
- `127.0.0.1:38457` - HTTP 代理端口
- `127.0.0.1:3880` - 管理端口

### 3. 使用代理

```bash
# curl 使用代理下载 GitHub Release
curl -x http://127.0.0.1:38457 -L -O "https://github.com/xxx/xxx/releases/download/v1.0/file.run"

# 或设置环境变量
export http_proxy=http://127.0.0.1:38457
export https_proxy=http://127.0.0.1:38457
```

### 4. Docker 状态管理

```bash
# 查看容器日志
docker logs fastgithub

# 重启容器
docker restart fastgithub

# 停止容器
docker stop fastgithub

# 更新镜像
docker pull slcnx/fastgithub:latest
docker stop fastgithub && docker rm fastgithub
# 重新运行上述 docker run 命令
```

## 工作原理

FastGitHub 通过以下方式加速 GitHub 访问：

1. **DNS 优化** - 内置 dnscrypt-proxy，选择最快的 GitHub CDN 节点 IP
2. **连接复用** - 保持长连接，减少 TLS 握手开销
3. **智能路由** - 自动选择延迟最低的 IP 地址
4. **HTTP 代理** - 提供标准 HTTP 代理接口，其他程序只需配置代理即可使用

## 端口说明

| 端口 | 用途 | 监听地址 |
|:---:|:----|:--------|
| 38443 | HTTPS 反向代理 | 127.0.0.1 |
| 38457 | HTTP 代理端口 | 127.0.0.1 |
| 3880 | 内部管理端口 | 127.0.0.1 |

> 所有端口均绑定在 127.0.0.1，仅限本机访问，安全可靠。

## 与 iStoreOS 其他容器配合使用

### 在 QwenPaw 容器中使用

QwenPaw 容器也使用 `--network host` 模式，因此可以直接使用 fastgithub 代理：

```bash
# 在 QwenPaw 中设置代理
export http_proxy=http://127.0.0.1:38457
export https_proxy=http://127.0.0.1:38457

# 下载 GitHub Release 文件
curl -x http://127.0.0.1:38457 -L -O "https://github.com/xxx/xxx/releases/..."
```

### 实测效果

| 文件 | 直连速度 | 使用代理 | 提升 |
|:----|:--------|:--------|:---:|
| OpenClash 19.7 MB | ~92 KB/s | ~295 KB/s | 3.2x |
| PassWall 74.5 MB | ~85 KB/s | ~290 KB/s | 3.4x |

## 鸣谢

- [FastGitHub](https://github.com/dotnetcore/FastGithub) - 原始项目
- 镜像维护者：slcnx/fastgithub
