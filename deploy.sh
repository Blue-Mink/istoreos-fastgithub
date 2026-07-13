#!/bin/sh
# ========================================
# iStoreOS FastGitHub 一键部署脚本
# 适用于 iStoreOS x86_64 / aarch64
# ========================================

set -e

echo "========================================"
echo "🚀 FastGitHub Docker 部署开始"
echo "========================================"

# 检查 Docker
if ! command -v docker >/dev/null 2>&1; then
    echo "❌ Docker 未安装，请先安装 Docker"
    exit 1
fi

# 检查 Docker 服务
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker 服务未运行"
    exit 1
fi

# 拉取镜像
echo "📥 拉取 FastGitHub 镜像..."
docker pull slcnx/fastgithub:latest

# 如果已存在同名容器，先删除
if docker ps -a --filter name=fastgithub | grep -q fastgithub; then
    echo "⚠️  发现已有 fastgithub 容器，先删除..."
    docker stop fastgithub 2>/dev/null || true
    docker rm fastgithub 2>/dev/null || true
fi

# 运行容器
echo "🐳 启动 FastGitHub 容器..."
docker run -d \
  --name fastgithub \
  --restart always \
  --network host \
  slcnx/fastgithub:latest

echo ""
echo "========================================"
echo "✅ FastGitHub 部署完成！"
echo "========================================"
echo ""
echo "📋 检查容器状态:"
docker ps --filter name=fastgithub --format "  {{.Names}}  {{.Status}}"
echo ""
echo "🔌 监听端口:"
echo "  - HTTP 代理:  http://127.0.0.1:38457"
echo "  - HTTPS 代理: https://127.0.0.1:38443"
echo ""
echo "💡 使用方式:"
echo '  export http_proxy=http://127.0.0.1:38457'
echo '  export https_proxy=http://127.0.0.1:38457'
echo '  curl -x http://127.0.0.1:38457 -L -O "https://github.com/.../file.run"'
echo ""
