# iStoreOS FastGitHub Docker 部署

在 **iStoreOS** 旁路由上通过 Docker 部署 **FastGitHub**，加速从 GitHub 的访问（git clone、下载 release 等）。

## 功能

- 🚀 加速 GitHub Release 下载（速度提升 3-5 倍）
- 🐳 基于 Docker 部署，不影响旁路由系统本身
- 🔄 容器自动重启，系统重启后自动恢复
- 🌐 支持 HTTP 代理模式，其他容器或设备均可使用
- 🏠 **全屋加速**：结合 dae 实现局域网所有设备自动加速 GitHub
- 🖥️ **LuCI 管理界面**：iStoreOS 网页管理 FastGitHub

---

## 一、部署 FastGitHub

### 环境要求

- 系统：iStoreOS 24.10.x（OpenWrt 变体）
- 架构：x86_64 / aarch64
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

## 二、LuCI 管理界面

FastGitHub 提供了 LuCI 网页管理界面，可在 iStoreOS 中方便地查看状态、修改端口和查看日志。

### 在线安装（从 Release 下载）

```bash
# 下载 LuCI 包
wget https://github.com/Blue-Mink/istoreos-fastgithub/releases/download/v1.0.0/luci-fastgithub.tar.gz

# 解压并安装
tar xzf luci-fastgithub.tar.gz -C /
./install.sh
```

### 手动安装

将仓库中 `luci/` 目录下的文件复制到对应位置：

| 文件 | 目标路径 |
|:----|:---------|
| `luci/controller/fastgithub.lua` | `/usr/lib/lua/luci/controller/fastgithub.lua` |
| `luci/model/cbi/fastgithub.lua` | `/usr/lib/lua/luci/model/cbi/fastgithub.lua` |
| `luci/view/fastgithub/fastgithub_status.htm` | `/usr/lib/lua/luci/view/fastgithub/fastgithub_status.htm` |
| `luci/view/fastgithub/fastgithub_log.htm` | `/usr/lib/lua/luci/view/fastgithub/fastgithub_log.htm` |
| UCI 配置（首次安装） | `/etc/config/fastgithub` |

安装后清除缓存：

```bash
rm -f /tmp/luci-*
```

然后刷新 LuCI 页面（Ctrl+F5），在 **服务 → FastGitHub** 中查看。

### LuCI 界面功能

| 功能 | 说明 |
|:----|:------|
| 🚀 **运行状态** | 显示容器运行状态、启动时间 |
| ▶️ **控制按钮** | 一键启动/停止/重启容器 |
| 🔧 **端口编辑** | 修改 HTTP/HTTPS 代理端口 |
| 📂 **路径显示** | 配置文件、证书、可执行文件路径 |
| 📋 **实时日志** | 每 5 秒自动刷新的容器日志查看器 |

---

## 三、全屋加速 GitHub 方案

### 方案 A：单设备配置代理（最简单）

在需要加速的 Windows/Mac/Linux 设备上设置 HTTP 代理：

| 系统 | 设置方法 |
|:----|:---------|
| **Windows** | 设置 → 网络 → 代理 → 开启「使用代理服务器」→ 地址=`192.168.3.125` 端口=`38457` |
| **macOS** | 系统设置 → 网络 → 高级 → 代理 → HTTP 代理 → `192.168.3.125:38457` |
| **Linux** | `export http_proxy=http://192.168.3.125:38457` |
| **Docker** | 设置环境变量 `HTTP_PROXY=http://192.168.3.125:38457` |

### 方案 B：dae 透明代理（推荐，无需配终端）

使用 **dae**（eBPF 代理）在旁路由上实现透明代理，所有设备无需任何设置自动走 fastgithub 加速 GitHub。

#### 1. 安装 dae

```bash
# 下载 dae 安装包
wget https://github.com/Blue-Mink/istoreos-fastgithub/releases/download/v1.0.0/dae_1.0.0_x86_64_all_sdk_24.10.run

# 安装
is-opkg dotrun dae_1.0.0_x86_64_all_sdk_24.10.run
```

#### 2. 配置 dae（关键步骤）

创建 `/etc/dae/config.dae`，将 fastgithub 作为上游代理：

```bash
cat > /etc/dae/config.dae << 'EOF'
global {
    tproxy_port: 12345
    tproxy_port_protect: true
    log_level: info
    wan_interface: auto
    lan_interface: br-lan
    auto_config_kernel_parameter: true
    tcp_check_url: 'http://cp.cloudflare.com'
    udp_check_dns: 'dns.google:53'
    check_interval: 30s
}

# 节点定义 - 将 fastgithub 作为上游代理
node 'fastgithub' {
    protocol: 'http'
    address: '127.0.0.1:38457'
}

# 路由分组
group 'github_accel' {
    node: 'fastgithub'
}

# 路由规则 - 只劫持 GitHub 相关流量
routing {
    domain(contains: 'github.com') -> 'github_accel'
    domain(contains: 'githubassets.com') -> 'github_accel'
    domain(contains: 'githubusercontent.com') -> 'github_accel'
    domain(contains: 'github.io') -> 'github_accel'
    domain(contains: 'githubapp.com') -> 'github_accel'
    domain(contains: 'githubstatus.com') -> 'github_accel'

    # 其余所有流量直连，不影响上网
    final: 'direct'
}
EOF
```

**配置说明：**

| 参数 | 值 | 说明 |
|:----|:---|:------|
| `lan_interface` | `br-lan` | 旁路由 LAN 口，劫持所有局域网设备 |
| `wan_interface` | `auto` | WAN 口自动检测 |
| `node address` | `127.0.0.1:38457` | fastgithub 代理端口 |
| `domain rules` | 6 个 GitHub 域名 | 只劫持 GitHub 流量，其他直连 |
| `final` | `direct` | 非 GitHub 流量直接放行 |

#### 3. 启用并启动 dae

```bash
# 启用开机自启
uci set dae.config.enabled=1
uci commit dae

# 验证配置语法
/usr/bin/dae validate -c /etc/dae/config.dae

# 启动 dae（首次启动较慢，eBPF 需要编译）
/etc/init.d/dae start

# 查看状态
/etc/init.d/dae status
```

#### 4. 验证全屋加速效果

在任意局域网设备上测试：

```bash
# 测试下载速度（对比直连和代理）
curl -s --max-time 15 -o /dev/null -w "直连: %{speed_download} B/s\n" \
  "https://github.com/..." --noproxy '*'

# 通过 dae 加速后（无需设置代理）
curl -s --max-time 15 -o /dev/null -w "加速: %{speed_download} B/s\n" \
  "https://github.com/..."
```

#### 5. 排错

```bash
# 查看 dae 运行日志
logread | grep dae | tail -20

# 检查 eBPF 程序是否加载
bpftool prog list 2>/dev/null | grep dae

# 重启 dae
/etc/init.d/dae restart

# 停止 dae（恢复直连）
/etc/init.d/dae stop
uci set dae.config.enabled=0
uci commit dae
```

---

## 四、实测效果

| 文件 | 直连速度 | 使用 fastgithub | 提升倍数 |
|:----|:--------|:---------------|:--------:|
| OpenClash 19.7 MB | ~92 KB/s | ~295 KB/s | 3.2x |
| PassWall 74.5 MB | ~80 KB/s | ~280 KB/s | 3.5x |
| dae 10.2 MB | ~85 KB/s | ~290 KB/s | 3.4x |

> 测试环境：iStoreOS 24.10.7 x86_64，旁路由模式，中国电信宽带

---

## 五、端口说明

| 端口 | 用途 | 监听地址 |
|:---:|:----|:--------|
| 38443 | HTTPS 反向代理 | 127.0.0.1 |
| 38457 | HTTP 代理端口 | 127.0.0.1 |
| 3880 | 内部管理端口 | 127.0.0.1 |

---

## 六、Docker 管理命令

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

## 七、文件结构

```
istoreos-fastgithub/
├── README.md                          # 本文件
├── docker-compose.yml                 # Docker Compose 配置
├── deploy.sh                          # 一键部署脚本
├── dae_config.dae                     # dae 透明代理配置示例
├── .gitignore
└── luci/                              # LuCI 管理界面
    ├── controller/
    │   └── fastgithub.lua
    ├── model/
    │   └── cbi/
    │       └── fastgithub.lua
    └── view/
        └── fastgithub/
            ├── fastgithub_status.htm
            └── fastgithub_log.htm
```

## 八、Release 下载内容

| 文件 | 说明 |
|:----|:------|
| `fastgithub_image.tar.gz` (195 MB) | Docker 镜像离线包，`docker load < fastgithub_image.tar.gz` |
| `dae_1.0.0_x86_64_all_sdk_24.10.run` (10.2 MB) | dae eBPF 代理插件 |
| `luci-fastgithub.tar.gz` (4.5 KB) | FastGitHub LuCI 管理界面插件 |

## 九、参考资料

- [FastGitHub 原项目](https://github.com/dotnetcore/FastGithub)
- [dae 项目](https://github.com/daeuniverse/dae)
- [iStoreOS 官方](https://www.istoreos.com/)
