# iStoreOS FastGitHub Docker 部署

在 **iStoreOS** 旁路由上通过 Docker 部署 **FastGitHub**，加速从 GitHub 的访问（git clone、下载 release 等）。

## 功能

- 🚀 加速 GitHub Release 下载（速度提升 3-5 倍）
- 🐳 基于 Docker 部署，不影响旁路由系统本身
- 🔄 容器自动重启，系统重启后自动恢复
- 🌐 支持 HTTP 代理模式，其他容器或设备均可使用
- 🏠 **全屋加速**：结合 dae 实现局域网所有设备自动加速 GitHub

---

## 一、部署 FastGitHub

### 环境要求

- 系统：iStoreOS 24.10.x（OpenWrt 变体）
- 架构：x86_64
- 已安装 Docker 和 dockerd 服务
- 至少 1GB 可用磁盘空间

### 快速部署

```bash
docker run -d \
  --name fastgithub \
  --restart always \
  --network host \
  slcnx/fastgithub:latest
```

### 验证

```bash
docker ps --filter name=fastgithub
netstat -tlnp | grep fastgithub
# 应看到 127.0.0.1:38443 / 38457 / 3880
```

---

## 二、全屋加速 GitHub 方案

### 方案 A：单设备配置代理（最简单）

在需要加速的 Windows/Mac/Linux 设备上设置 HTTP 代理：

| 系统 | 设置方法 |
|:----|:---------|
| **Windows** | 设置 → 网络 → 代理 → 开启「使用代理服务器」→ 地址=`192.168.3.125` 端口=`38457` |
| **macOS** | 系统设置 → 网络 → 高级 → 代理 → HTTP 代理 → `192.168.3.125:38457` |
| **Linux** | `export http_proxy=http://192.168.3.125:38457` `export https_proxy=http://192.168.3.125:38457` |
| **Docker 容器** | 设置环境变量或 `--network host` 模式使用 `127.0.0.1:38457` |

> ⚠️ 注意：fastgithub 默认监听 127.0.0.1，如需 LAN 访问需在容器内额外配置或使用 iptables 转发。

### 方案 B：全屋透明代理（推荐，无需配终端）

使用 **dae**（eBPF 代理）在旁路由上实现透明代理，让所有设备自动走 fastgithub 加速 GitHub。

#### 1. 安装 dae

dae 已包含在仓库 Release 中，可直接下载安装：

```bash
# 下载 dae 安装包
wget https://github.com/Blue-Mink/istoreos-fastgithub/releases/download/v1.0.0/dae_1.0.0_x86_64_all_sdk_24.10.run

# 安装
is-opkg dotrun dae_1.0.0_x86_64_all_sdk_24.10.run
```

#### 2. 配置 dae

创建 `/etc/dae/config.dae`，将 fastgithub 作为 upstream 代理：

```bash
cat > /etc/dae/config.dae << 'EOF'
global {
    tproxy_port: 12345
    tproxy_port_protect: true
    log_level: info
    wan_interface: auto
    auto_config_kernel_parameter: true
    tcp_check_url: 'http://cp.cloudflare.com'
    udp_check_dns: 'dns.google:53'
    check_interval: 30s
    lan_interface: br-lan
}

# 节点定义 - 使用 fastgithub 作为 upstream
node 'fastgithub' {
    protocol: 'http'
    address: '127.0.0.1:38457'
}

# 路由分组
group 'github_accel' {
    node: 'fastgithub'
}

# 路由规则 - 只代理 GitHub 相关的流量
routing {
    # GitHub 域名走 fastgithub 加速
    domain(contains: 'github.com') -> 'github_accel'
    domain(contains: 'githubassets.com') -> 'github_accel'
    domain(contains: 'githubusercontent.com') -> 'github_accel'
    domain(contains: 'github.io') -> 'github_accel'

    # 其余流量直连
    final: 'direct'
}```

#### 3. 启用并启动 dae

```bash
# 设置开机自启
uci set dae.config.enabled=1
uci commit dae

# 验证配置
/usr/bin/dae validate -c /etc/dae/config.dae

# 启动 dae
/etc/init.d/dae start
```

#### 4. 验证全屋加速效果

```bash
# 在任意局域网设备上测试
curl -s --max-time 10 -o /dev/null -w "%{speed_download} B/s\n" "https://github.com/..."
```

### 方案 C：iptables 转发（轻量方案）

如果不想安装 dae，可以用 iptables 在旁路由上做流量劫持：

```bash
# 创建 GitHub IP 地址列表转向 fastgithub
cat > /etc/fastgithub_redirect.sh << 'SH'
#!/bin/sh
# 将访问 GitHub 的流量重定向到 fastgithub 代理
PROXY_IP="127.0.0.1"
PROXY_PORT="38457"

# GitHub 相关域名解析后的 IP 段（示例，实际应使用更完整的列表）
GITHUB_RANGES="
140.82.112.0/20
185.199.108.0/22
192.30.252.0/22
"

for range in $GITHUB_RANGES; do
  iptables -t nat -A OUTPUT -d "$range" -p tcp --dport 443 -j DNAT --to-destination $PROXY_IP:$PROXY_PORT
  iptables -t nat -A OUTPUT -d "$range" -p tcp --dport 80 -j DNAT --to-destination $PROXY_IP:$PROXY_PORT
done
SH
chmod +x /etc/fastgithub_redirect.sh
```

> 注意：iptables 方式较为复杂，推荐使用方案 B（dae 透明代理）。

---

## 三、实测效果

| 文件 | 直连速度 | 使用 fastgithub | 提升倍数 |
|:----|:--------|:---------------|:--------:|
| OpenClash 19.7 MB | ~92 KB/s | ~295 KB/s | 3.2x |
| dae 10.2 MB | ~85 KB/s | ~290 KB/s | 3.4x |
| PassWall 74.5 MB | ~80 KB/s | ~280 KB/s | 3.5x |

> 测试环境：iStoreOS 24.10.7 x86_64，中国电信宽带

---

## 四、端口说明

| 端口 | 用途 | 监听地址 |
|:---:|:----|:--------|
| 38443 | HTTPS 反向代理 | 127.0.0.1 |
| 38457 | HTTP 代理端口 | 127.0.0.1 |
| 3880 | 内部管理端口 | 127.0.0.1 |

---

## 五、Docker 管理命令

```bash
# 查看日志
docker logs fastgithub

# 重启
docker restart fastgithub

# 更新
docker pull slcnx/fastgithub:latest
docker stop fastgithub && docker rm fastgithub
docker run -d --name fastgithub --restart always --network host slcnx/fastgithub:latest

# 卸载
docker stop fastgithub && docker rm fastgithub
docker rmi slcnx/fastgithub:latest
```

## 六、文件结构

```
istoreos-fastgithub/
├── README.md                  # 本文件
├── docker-compose.yml         # Docker Compose 配置
├── deploy.sh                  # 一键部署脚本
├── dae_config.dae             # dae 透明代理配置示例
└── .gitignore
```

## 七、参考资料

- [FastGitHub 原项目](https://github.com/dotnetcore/FastGithub)
- [dae 项目](https://github.com/daeuniverse/dae)
- [iStoreOS 官方](https://www.istoreos.com/)
