# magpie 网关（服务器部署）

把本机跑通的 magpie 搬到服务器，客户端通过域名调用。

本目录只放**服务器侧**的部署材料；本地开发用的 magpie 直接跑在 `../docker-compose.yml` 里。

## 架构

```
oc / omp（任意网络）
      │  https://gw.<域名>/v1  +  sk-magpie-key-…
      ▼
Cloudflare（橙云，Universal SSL 自动签发 + 自动续期）
      │  http 或 https 回源
      ▼
OpenResty :80 / :443
      │  http（容器网络内）
      ▼
magpie:3430（同时服务 / 和 /v1）
      │
      ├─ OpenCode Go
      ├─ WorkBuddy（国内 + 国际）
      └─ Antigravity（Google AI Pro）
```

**必须橙云**：Cloudflare 的免费证书只发给 proxied 记录（[Universal SSL 文档](https://developers.cloudflare.com/ssl/edge-certificates/universal-ssl/)）。灰云时 CF 不参与 TLS，就得自己在源站签证书。

橙云带来的附带好处：隐藏源站 IP、WAF 可用、控制台以后能挂 CF Access。代价是 CF 对首字节有 100 秒限制——对 SSE 基本无感，因为流式一开始就持续吐数据。

## 回源方式

| 模式 | CF → 源站 | 源站要做什么 | 续期 |
|---|---|---|---|
| **Flexible**（最省事） | HTTP 明文 | 只开 80，不用证书 | 无 |
| **Full (strict)** | HTTPS | 装一张 Cloudflare Origin CA 证书（15 年有效） | 不用续 |

网关里存着三家上游的完整凭证，Cloudflare 到你服务器这一跳如果走明文，等于把令牌放在公网上跑。建议 **Full (strict)**：Origin CA 在 CF 后台点几下就签发，有效期 15 年，不存在续期问题。

## 部署步骤

1. **CF**：给 `gw.<域名>` 加 A 记录指向服务器，**开启橙云**；SSL/TLS 模式选 **Flexible**（源站不需要证书，CF 用 http 回源）
2. **迁配置**：把本地 `~/.laradock/data/magpie` 打包带到服务器（`example/migrate-config.sh`）
3. **起容器**：见下方「服务器也是 laradock」
4. **配反代**：`example/nginx.magpie.conf` 放进 OpenResty 的 sites 目录，reload
5. **客户端**：把 `example/opencode.fragment.json` / `example/omp.fragment.yml` 合进各自配置

## 服务器也是 laradock

magpie 的服务块已经在本仓库 `docker-compose.yml` 末尾（提交 `7f84dff6`）。服务器上直接拉这个分支即可：

```bash
cd /path/to/laradock
git fetch origin local && git checkout local && git pull
```

然后在服务器的 `.env` 里加：

```ini
### magpie ###
MAGPIE_VERSION=latest
# 端口绑定地址（宿主机侧）：
#   172.19.0.1  仅 Docker 内网 + 宿主机，nginx 反代走得到，公网碰不到（推荐）
#   127.0.0.1   仅宿主机回环，nginx 在容器里到不了，反代会失败
#   0.0.0.0     所有网卡，公网可直连 IP:3425/3430，绕过 Cloudflare 的限速与 WAF，别用
MAGPIE_BIND=172.19.0.1
MAGPIE_PORT=3425
MAGPIE_WEB_PORT=3430
MAGPIE_WEB_KEY=<openssl rand -hex 16>
MAGPIE_PUBLIC_URL=https://ai.<域名>
```

启动：

```bash
docker compose -f docker-compose.yml up -d magpie
docker logs -f laradock-magpie-1
```

> 服务器上如果 laradock 有本地改动，先 `git status` 看清楚再拉，别直接覆盖。

### 数据目录属主（必做）

镜像以 `nonroot`（uid 65532）运行。`${DATA_PATH_HOST}/magpie` 如果是 root 建的目录，容器会一直报：

```
plugins.yml: mkdir /config/magpie: permission denied
catalog: mkdir /config/cache: permission denied
```

修法（任选其一，推荐 chown）：

```bash
sudo chown -R 65532:65532 /root/.laradock/data/magpie   # 推荐
sudo chmod 777 /root/.laradock/data/magpie              # 省事，但入口目录对所有人可写
```

容器健康检查不碰磁盘，所以报这个错时状态仍显示 `healthy`，别被误导。

### 资源库前置依赖：node / uv（必做）

官方镜像基于 Debian 12，**除 `/magpie` 外没有任何运行时**：node、npm、npx、python3、uv、uvx、git 全都没有。
magpie 的「资源库」用 `exec.LookPath` 找 `npx` / `uvx` 拉起 MCP 服务（源码 `internal/library/mcp_check.go` 的 `stdioProgram`），找不到就报 `notfound`，所以新增资源库条目时会提示找不到 npx/uvx。

不改镜像（自建镜像会让「pull 上游 latest + 比对镜像 ID」的蓝绿升级失效），改为把运行时挂进容器：

```bash
sudo mkdir -p /root/.laradock/data/magpie-runtime/{node,uv}
# Node 22（含 npm/npx），官方 arm64 tarball，需要 glibc ≥ 2.28（Debian 12 是 2.36）
sudo curl -fsSL https://nodejs.org/dist/v22.23.4/node-v22.23.4-linux-arm64.tar.xz \
  | sudo tar -xJ -C /root/.laradock/data/magpie-runtime/node --strip-components=1
# uv / uvx（静态二进制）
sudo curl -fsSL https://github.com/astral-sh/uv/releases/download/0.9.2/uv-aarch64-unknown-linux-gnu.tar.gz \
  | sudo tar -xz -C /root/.laradock/data/magpie-runtime/uv --strip-components=1
```

`git` 只给「git」这一个资源库条目用（`uvx mcp-server-git` 真的会调用 git 命令）。从 Debian 包里提取，不改镜像：

```bash
sudo docker run --rm -v /root/.laradock/data/magpie-runtime:/out debian:12 bash -c \
  'apt-get update -qq && apt-get install -y -qq --no-install-recommends git ca-certificates
   mkdir -p /out/git/bin /out/git/lib /out/git/libexec
   cp /usr/bin/git /out/git/bin/git.real
   cp -a /usr/lib/git-core /out/git/libexec/git-core
   cp -a /usr/share/git-core /out/git/share-git-core   # 之后 mv 成 /out/git/share/git-core
   cp /etc/ssl/certs/ca-certificates.crt /out/git/
   for b in /usr/bin/git /usr/lib/git-core/git-remote-http /usr/lib/git-core/git-remote-https; do
     [ -x "$b" ] && ldd "$b"; done | awk "/=> \//{print \$3}" | sort -u |
   while read l; do case "$(basename $l)" in libc.so.6|libpthread.so.0|libdl.so.2|libm.so.6|libresolv.so.2|librt.so.1|ld-linux*) continue;; esac; cp -L "$l" /out/git/lib/; done'
```

再放一个包装脚本 `.../magpie-runtime/git/bin/git`（`git.real` 才是真二进制）：

```sh
#!/bin/sh
export LD_LIBRARY_PATH=/opt/git/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
export GIT_EXEC_PATH=/opt/git/libexec/git-core
export GIT_SSL_CAINFO=/opt/git/ca-certificates.crt
export GIT_TEMPLATE_DIR=/opt/git/share/git-core/templates
exec /opt/git/bin/git.real "$@"
```

glibc 系列（`libc`/`libpthread`/`libdl`/`libm`）**不要**打进包，用容器自带的，否则容易版本冲突。

`docker-compose.yml` 里已声明：

```yaml
      volumes:
        - ${DATA_PATH_HOST}/magpie-runtime/node:/opt/node:ro
        - ${DATA_PATH_HOST}/magpie-runtime/uv:/opt/uv:ro
        - ${DATA_PATH_HOST}/magpie-runtime/git:/opt/git:ro
      environment:
        PATH: "/opt/git/bin:/opt/node/bin:/opt/uv:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        npm_config_cache: "/config/cache/npm"
        UV_CACHE_DIR: "/config/cache/uv"
        UV_PYTHON_INSTALL_DIR: "/config/cache/uv-python"
```

- 缓存都落在 `/config/cache`：升级时 rsync 排除该目录，不随容器重建丢包、也不扩大复制量。
- `npx -y <包>` 安装的 MCP 包在 `/config/magpie/mcp-npm/`（共享数据卷），升级不丢，magpie 自己按天清理没在用的。
- 缺运行时的时候蓝绿脚本会直接放弃升级（`magpie.sh` 开头检查 `node/bin/npx`、`uv/uvx`），不会把「缺运行时」变成一次难查的升级。

验证：

```bash
docker exec laradock-magpie-1 sh -c 'node -v; npm -v; uv --version; uvx --version; git --version'
```

### playwright 资源库：Chromium 系统库

`playwright` 条目（`npx -y @playwright/mcp@latest`）真正驱动浏览器还需要 Chromium 的系统库，官方镜像里 `libnss3`、`libgbm`、`libasound`、`libX11` 等全都没有，而容器是非 root（uid 65532），跑不了 `npx playwright install --with-deps`。

同样是提取后挂载，不改镜像：

```bash
# 在 debian:12 里装齐依赖，把 chrome 与 chrome-headless-shell 的 ldd 依赖库抽出来
sudo docker run --rm -v <已下载的浏览器目录>:/pw:ro \
  -v /root/.laradock/data/magpie-runtime:/out -v ./pw-bundle.sh:/bundle.sh:ro \
  --entrypoint bash debian:12 /bundle.sh
```

`pw-bundle.sh` 做三件事：`apt-get install` Chromium 依赖 → 对两个可执行文件跑 `ldd` 抽出所有 `/lib/...` 库（**排除 glibc 系列**：`libc.so.6`/`libpthread`/`libdl`/`libm`/`libresolv`/`librt`，用容器自带的避免版本冲突）→ 拷字体到 `pw/fonts`。产出约 34MB。

`docker-compose.yml` 里已声明：

```yaml
        - ${DATA_PATH_HOST}/magpie-runtime/pw:/opt/pw:ro
      environment:
        LD_LIBRARY_PATH: "/opt/pw/lib"
        PLAYWRIGHT_BROWSERS_PATH: "/config/cache/pw-browsers"
```

Chromium 本体（407MB，playwright 1.65-alpha 锁定的 chromium-1252）已放进 `$RUNTIME_DIR/pw/chrome/`，通过 `/config/cache/pw-mcp.json`（`executablePath=/opt/pw/chrome/chrome`、`chromiumSandbox: false`，容器内无沙箱内核）注入 @playwright/mcp；该配置文件 rsync 排除、升级不复制。

验证：

```bash
docker exec laradock-magpie-1 sh -c 'ldd $PLAYWRIGHT_BROWSERS_PATH/chromium_headless_shell-*/chrome-headless-shell-linux-arm64/chrome-headless-shell | grep "not found"'
```

无输出即依赖齐全。

### 网络：反代为什么写 172.19.0.1

宿主机在 laradock 网桥上有一个固定地址 `172.19.0.1`。magpie 端口绑到这个地址后：

```nginx
proxy_pass http://172.19.0.1:3430;
```

- nginx（容器内）走 docker 网桥能到 ✅
- 公网打不到，`http://<服务器IP>:3430` 直接连不上 ✅
- 不依赖容器名解析，magpie 容器不在时 openresty 重启也不会失败 ✅

**不要绑 `127.0.0.1`**：那是容器自己的回环，nginx 在另一个容器里，会得到 connection refused。

**也不要绑 `0.0.0.0`**：等于把 3425/3430 挂到公网，CF 的限速、WAF、以后可能加的 Access 全部可被绕过。

> 早期这节写的是「openresty 只在 frontend 网络、必须绑 0.0.0.0」，实测不成立——openresty 同时在 `backend` 网络（`172.19.0.6`），绑 `172.19.0.1` 完全可用，且更安全。

### 已部署实例（2026-11-05）

| 项 | 值 |
|---|---|
| 域名 | `ai.kilvn.com`（CF 橙云，Flexible 回源） |
| 反代 | `/www/laradock/nginx/sites/ai.kilvn.com.conf` → `172.19.0.1:3430` |
| 绑定 | `MAGPIE_BIND=172.19.0.1`（公网不可直连） |
| 数据 | `/root/.laradock/data/magpie`（65532 属主） |
| 网关 | `https://ai.kilvn.com/v1`（3430 同时服务控制台与 API） |
| 升级 | 每 10 分钟 cron，蓝绿切换；退役等待按连接数自适应（默认上限 700s） |
| 数据保留 | 对话记录每天 04:35 清理，保留 30 天（`magpie_retention.sh`） |

> 蓝绿期间临时容器只发布 `172.19.0.1:13430`，不接管 3425。走域名的客户端完全无感；如果有客户端直连 `3425`，在正式容器重建的 1–2 秒里会断。
>
> **退役等待（`MAGPIE_DRAIN`，默认 700s）**：切走流量后每 5 秒采样退役容器 `3430` 的 ESTABLISHED 连接数，清空就立刻收尾，最长等 700s。原来固定 120s 会掐断长请求——实测 p99.9 是 303s、最长 598s，被掐断的请求连用量都不写（等于静默失败）。控制台开着 SSE 时连接数不会归零，整轮会走满上限，期间 cron 的下一轮因 flock 拿不到锁而跳过（日志可见）。

注意：`nginx/sites/*.conf` 被 `nginx/sites/.gitignore` 排除（`*.conf`），vhost 属于每台机器自己的配置，**不在仓库里同步**，换机器时按 `example/nginx.magpie.conf` 重新放一份。

### Flexible 的两个前提

1. 源站 **80 端口必须对 CF 开放**（CF 用 http 回源）；443 可以不开
2. 反代里**不要写 301 跳 https**——CF 回源是 http，跳转会导致死循环。`example/nginx.magpie.conf` 已经按这个写了

## 环境变量

| 变量 | 说明 |
|---|---|
| `MAGPIE_VERSION` | 镜像标签，`latest` 或 `stable` |
| `MAGPIE_WEB_KEY` | 控制台 key，`openssl rand -hex 16`，改了旧登录失效 |
| `MAGPIE_PUBLIC_URL` | **客户端实际访问的地址**，写 `https://gw.<域名>`，否则日志和客户端拿到容器内网地址 |

两个都不要设：

- `MAGPIE_TLS_CERT` / `MAGPIE_TLS_KEY`：一旦设置，magpie 会拒绝明文 HTTP，而反代回源是 http，会 400
- `MAGPIE_ALLOW_IPS`：它只看连接来源地址、不信任 `X-Forwarded-For`，橙云下所有请求都来自 CF 段，设了会全拒

## 安全现状（已知取舍）

控制台和网关同域同端口，保护只有 `MAGPIE_WEB_KEY` 这一个 URL 参数。拿到链接的人可以改供应商、看所有上游凭证。

这是当前选定的方案。要收紧的话，在 `example/nginx.magpie.conf` 的 `location /` 里加 `allow/deny`，或在 CF 上给控制台路径加 Access 策略。

## 验证

```bash
# 1. 容器
docker ps | grep magpie

# 2. 网关鉴权
curl -s -o /dev/null -w '%{http_code}\n' https://gw.<域名>/v1/models          # 期望 401
curl -s -o /dev/null -w '%{http_code}\n' https://gw.<域名>/v1/models \
  -H "Authorization: Bearer sk-magpie-key-…"                                  # 期望 200

# 3. 真实调用
curl -s https://gw.<域名>/v1/chat/completions \
  -H "Authorization: Bearer sk-magpie-key-…" \
  -H 'Content-Type: application/json' \
  -d '{"model":"group/coding","messages":[{"role":"user","content":"say ok"}],"max_tokens":16}'

# 4. 流式
curl -N https://gw.<域名>/v1/chat/completions \
  -H "Authorization: Bearer sk-magpie-key-…" \
  -H 'Content-Type: application/json' \
  -d '{"model":"group/coding","messages":[{"role":"user","content":"say ok"}],"stream":true}'

# 5. 客户端
opencode run -m magpie/coding "只回复两个字：收到"
```

## 常见问题

| 现象 | 原因 |
|---|---|
| 401 `not an enabled magpie gateway key` | 客户端没带网关密钥，或用的是旧的 |
| 400 明文 HTTP 被拒 | 误设了 `MAGPIE_TLS_CERT` |
| 日志里地址是 `172.x.x.x` | `MAGPIE_PUBLIC_URL` 没设或写错 |
| SSE 卡住不动 | 反代缺 `proxy_buffering off` |
| 控制台打不开 | 反代指到了 3425 而不是 3430（3430 同时服务 `/` 和 `/v1`） |
| 524 | CF 100 秒没等到首字节，检查上游是否超时 |
| 521/522 | CF 连不上源站，检查 80/443 和防火墙 |
