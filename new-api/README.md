# New API 网关（laradock 内）

统一模型入口：所有终端（OpenCode / omp / 其他 OpenAI 兼容客户端）只连这一个地址，
上游供应商、key、模型映射全部在 Web 控制台里改，客户端不动。

## 目录

```
new-api/
├── README.md          本文档
└── example/           模板，全部是「照抄改占位符」用，不参与运行
    ├── init.sql               建库建用户
    ├── newapi.conf            OpenResty 反代（默认不启用）
    ├── opencode.fragment.json OpenCode v2 客户端片段（纯 JSON）
    └── omp.fragment.yml       omp 客户端片段（YAML）
```

`example/` 里只有模板，没有真实密码、没有真实令牌。真实配置在 `../.env` 和 `../docker-compose.yml`。

## 依赖

| 组件 | 来源 | 说明 |
|---|---|---|
| 镜像 | `calciumion/new-api:latest` | 定义在 `../docker-compose.yml` 的 `new-api` 服务 |
| 数据库 | laradock `mariadb` 容器 | 库 `new_api`，用户 `newapi`（MariaDB 13，实测可用） |
| 缓存 | laradock `redis` 容器 | 用 db 3，避开其他项目 |
| 反代 | laradock `openresty`（可选） | 默认不用，直连 3101 |

变量全部在 `../.env` 的 `### New API ###` 段落里，本目录不存任何密钥。

> 端口说明：laradock 的 `GRAFANA_PORT` 已占用 3100，所以 New API 用 **3101**。改端口只改 `NEW_API_PORT`。

## 环境变量（在 `../.env`，模板见 `../.env.example`）

| 变量 | 当前值 | 说明 |
|---|---|---|
| `NEW_API_VERSION` | `latest` | 镜像 tag |
| `NEW_API_PORT` | `3101` | 宿主机端口 |
| `NEW_API_DB_NAME` | `new_api` | 库名 |
| `NEW_API_DB_USER` | `newapi` | 专用账号，不用 root |
| `NEW_API_DB_PASSWORD` | 随机 | 与 `init.sql` 时设置的一致 |
| `NEW_API_REDIS_DB` | `3` | 独立 db index |
| `NEW_API_SESSION_SECRET` | 随机 | 固定不变，换了登录态全失效 |
| `NEW_API_SESSION_COOKIE_SECURE` | `false` | 内网 HTTP 用 `false`；上 HTTPS 反代后改 `true` |
| `NEW_API_SESSION_COOKIE_TRUSTED_URL` | 空 | refresh/logout 的可信 Origin。仅 `SECURE=true` 时填，留空即关闭校验 |

两个 Cookie 变量是**互锁**的（已实测源码行为，配错容器直接退出）：

| SECURE | TRUSTED_URL | 结果 |
|---|---|---|
| `false` | 空 | ✅ 正常（当前配置） |
| `true` | 有值 | ✅ 正常，Origin 校验生效 |
| `false` | 有值 | ❌ 启动失败：`SESSION_COOKIE_TRUSTED_URL requires SESSION_COOKIE_SECURE=true` |
| `true` | 空 | ❌ 启动失败：`SESSION_COOKIE_SECURE=true requires SESSION_COOKIE_TRUSTED_URL` |

数据库和缓存的主机名**复用 laradock 已有的 `DB_HOST` / `REDIS_HOST`**，不再另建变量。
`DB_HOST` 从 `mysql` 改成了 `mariadb`，因为本机实际运行的是 mariadb 容器，`mysql` 容器并未启动。

端口 `3306` / `6379` 是**容器内**的固定端口，直接写在 compose 里。不能换成 `MARIADB_PORT` / `REDIS_PORT`——
那两个是宿主机映射端口，改了也不会改变容器网络内的监听端口，写进连接串会连不上。

## 日常运维

```bash
cd ~/Documents/web/laradock

# 启动
docker compose -f docker-compose.yml up -d --no-deps new-api

# 看日志
docker logs -f laradock-new-api-1

# 停止 / 重启
docker compose -f docker-compose.yml stop new-api
docker restart laradock-new-api-1

# 健康检查
curl -s --noproxy '*' http://127.0.0.1:3101/api/status
```

控制台：`http://127.0.0.1:3101`，外部设备用 `http://<tailscale-ip>:3101`。

> `--no-deps` 必须带：`mariadb` / `redis` 在 compose 里是 `build:` 定义，
> 不带这个参数 compose 会去检查依赖、可能触发重建，把正在跑的数据库卷进来。

## 配置模型的三层结构

1. **渠道**：一个上游一条，填 key + base URL，点「获取模型列表」自动拉回可用模型。
2. **模型重定向**：把上游真实模型名映射成稳定别名（`fast` / `code` / `think`）。
3. **令牌**：一台机器一个，限制可用模型与额度。

客户端只认别名。换供应商、换 key、换上游模型时只改第 1、2 层，客户端无感。

**可用性路由**：同一个别名挂多条渠道，设优先级，主渠道失败自动切备用。

## 关于配置文件格式

- **JSON 不支持注释**。`example/opencode.fragment.json` 是纯 JSON，说明文字全在本文档里。
  直接把它合并进 `~/.config/opencode/opencode.json` 不会报错。
- 想要带注释的 JSON，规范叫 **JSONC**（`.jsonc`，VS Code 和 OpenCode 都支持），
  但你的现有配置是 `opencode.json`，不要混用扩展名，否则读取行为不一致。
- **JSONP 不是这个用途**：它是把 JSON 包一层回调函数供 `<script>` 跨域加载，跟配置文件无关。
- YAML、nginx、SQL 原生支持注释，`example/` 里这三个文件保留了解释性注释。

## 本地 vs 线上

| 环境 | `SESSION_COOKIE_SECURE` | `TRUSTED_URL` | 控制台地址 |
|---|---|---|---|
| 本地开发 | `false` | 留空 | `http://127.0.0.1:3101` |
| 线上（Cloudflare 代理） | `true` | `https://<域名>` | `https://<域名>` |

**当前是本地配置，不要开 Secure**——开了之后浏览器用 `http://` 访问会登录不上（Secure Cookie 不会在 HTTP 下发送）。

### 线上启用 HTTPS 的完整步骤

1. Cloudflare 加一条 DNS 记录（A 或 CNAME）指向服务器，代理开关打开。
2. `example/newapi.conf` → 复制到 `../../nginx/sites/newapi.conf`，替换 `<DOMAIN>`。
3. 可选：解开文件里 Cloudflare 真实 IP 的注释，网段从 `https://www.cloudflare.com/ips-v4` 拉最新。
4. reload 反代：

   ```bash
   docker exec laradock-openresty-1 nginx -t
   docker exec laradock-openresty-1 nginx -s reload
   ```

5. 改 `.env` 两个变量，必须同时改：

   ```ini
   NEW_API_SESSION_COOKIE_SECURE=true
   NEW_API_SESSION_COOKIE_TRUSTED_URL=https://<域名>
   ```

6. 重建容器：

   ```bash
   docker compose -f docker-compose.yml up -d --no-deps --force-recreate new-api
   ```

7. 验证：浏览器打开 `https://<域名>`，登录后刷新页面，登录态仍在；再打开 `http://<服务器IP>:3101`，应当无法登录（这是预期）。

> 回源模式建议用 Cloudflare **Full (strict)** + Origin CA 证书（15 年有效期）。
> Flexibility 模式下 CF → 源站是明文 HTTP，网关的 `sk-` 令牌会在这段裸奔。
> 切换源头证书要动 OpenResty 的 443，与其他站点共用，建议单独一次做。

## 接入 OpenCode（Go 订阅 / Console 按量付费）

OpenCode 有两套计费入口，**端点不同，填错会报 `Insufficient account funds`**：

| 计费方式 | 渠道里填的 API 地址 | 说明 |
|---|---|---|
| **Go 订阅** | `https://opencode.ai/inference/go/openai` | 走订阅额度 |
| Console 按量付费 | `https://opencode.ai/inference/openai` | 走账户余额，无余额即 402 |
| 免费模型 | — | 只允许在 OpenCode 客户端内使用，走 API 一律 429 |

### Go 渠道的三个必填项

1. **类型**：OpenAI
2. **API 地址**：`https://opencode.ai/inference/go/openai`
3. **请求头覆盖**（`header_override`）：

   ```json
   {"x-opencode-session": "new-api-gw-001"}
   ```

   缺这个头会返回 `400 MissingSessionID`。User-Agent 不校验，随便填。
   值只能是固定字符串，所有会话共用一个 session id —— 功能正常，但 prompt cache 命中率不如原生客户端。

### 渠道分组必须和令牌分组一致

渠道建好后默认分组是 `vip` 时，用 `default` 分组的令牌调用会返回
`503 No available channel for model xxx under group default`。
把渠道的「分组」改成 `default`（或让令牌用 `vip`）即可。

### Go 覆盖的模型（24 个）

```
deepseek-v4.1-flash, deepseek-v4-pro, glm-5.3, glm-5.3-flash,
kimi-k3, kimi-k3.1-pro, kimi-k2.7-code, longcat-2.0,
mimo-v2.6-flash, mimo-v2.6-pro, minimax-m3, minimax-m3.1-flash,
step-5-preview, hy4-preview, hy3, qwen3.8-max, qwen3.8-flash,
claude-haiku-5-5, grok-4.7, gemini-4-argon,
gpt-5.6-luna, gpt-6-luna, beam-free, iceman-contributor-free
```

注意：

- **Claude Sonnet / Opus、GPT-5 主力不在 Go 里**，只有 Haiku 5.5 和 Luna 系列。
- Console 会做协议转换，所以 Claude、Gemini、Grok 都能走上面的 OpenAI chat 端点，不需要单独建渠道。
- **GPT 系列在中国大陆返回 403** `unsupported_country_region_territory`，不是配置问题。

## 主备模型（优先级 + 模型重定向）

Go 订阅**按模型分额度**，所以「主模型 + 备用模型」是成立的：主模型额度耗尽后自动切备用。

### 配置方式

同一个模型名挂在两个渠道上，靠 `priority` 决定先后，备用渠道用「模型重定向」把它转成另一个模型：

| 渠道 | priority | models | model_mapping |
|---|---|---|---|
| 主 | 100 | `deepseek-v4.1-flash` 等 | 空 |
| 备 | 50 | `deepseek-v4.1-flash,glm-5.3` | `{"deepseek-v4.1-flash":"glm-5.3"}` |

客户端始终请求 `deepseek-v4.1-flash`，主渠道挂了自动降级到 `glm-5.3`，客户端无感。

三个必要条件：

1. 备用渠道的**模型列表必须包含被请求的模型名**（否则它不会成为候选）
2. 两个渠道的 `header_override` 用**不同的 session 值**，避免被上游当成同一会话
3. `设置 → 运营设置 → 重试次数` ≥ 1

### 重试规则（源码 `setting/operation_setting/status_code_ranges.go`）

```
可重试：1xx、3xx、4xx（除 400、408）、5xx（除 504、524）
永不重试：错误码 BadResponseBody
自动禁用渠道：401
```

所以 Go 额度耗尽返回的 402/429 能正确触发切换。

### 同 key 不是真冗余

两个渠道共用同一把 key、同一个订阅。订阅整体失效（欠费、封号）时两个都挂。
真要冗余必须接第二家厂商（DeepSeek 官方 / 智谱 / Kimi 等），步骤同上，只换 key 和 base URL。

## 选型对比（2026-11-03 调研）

当时的目标是「集中管理多个 token，并在某个 token 不可用时自动切换」。三个候选的能力边界：

| 维度 | New API（当前采用） | sub2api | Cardinal |
|---|---|---|---|
| 定位 | 多渠道 API 网关 | 订阅账号池分发 | headless 多供应商路由 |
| 集中管理 key | 渠道多密钥（随机/轮询） | 账号表（OAuth + API Key） | providers + keys |
| 故障切换 | 优先级 + 失败重试 | 组内切账号 | ordered + 每 key 冷却 |
| 额度感知路由 | 否，只按优先级 | 部分 | 是，定时探测余额端点 |
| 模型级主备 | 模型重定向（ds→glm） | 无此概念 | 路由别名 |
| 跨分组/跨模型降级 | 支持 | **不支持**，见 issue #1294 / #2313 / #2458 | 支持 |
| 协议转换 | OpenAI / Anthropic / Gemini | 同 | Chat / Responses / Messages / Gemini |
| Web 控制台 | 有 | 有 | **无**，仅管理 API |
| 数据库 | MariaDB（本机已有） | PostgreSQL 15+ | PostgreSQL |
| 部署方式 | 官方镜像 | 镜像 / 二进制 | **仅源码编译** |
| 成熟度 | 高 | 活跃，2k+ issues | 2026-10-17 创建，6 star，无 release |
| 许可 | AGPL-3.0 | LGPL-3.0 | GPL-3.0 |

### 结论

- **当前场景（OpenCode Go 订阅 + 厂商 API key）用 New API 足够**，主备切换已实测通过。
- **sub2api** 唯一不可替代的能力是 OAuth 订阅账号池（Claude Max / ChatGPT Plus），需要拼车共订阅时才引入；代价是新增 PostgreSQL，且跨分组不会自动降级。
- **Cardinal** 的路由模型最贴近「按额度自动选」的诉求，但额度探测依赖上游提供余额查询接口；OpenCode Go 目前没有这类端点，接进来会退化成普通 failover。加上零 release、无 Dockerfile、项目仅两周，暂不作为主网关，保留观察。

三者组合使用没有收益：任选其一作为唯一门面，其余最多作为它的上游渠道。

## 升级（跟随 latest）

```bash
cd ~/Documents/web/laradock
docker compose -f docker-compose.yml pull new-api
docker compose -f docker-compose.yml up -d --no-deps new-api
docker logs laradock-new-api-1 | tail -20
```

回滚：`docker image ls | grep new-api` 找到旧镜像 digest，把 `.env` 里
`NEW_API_VERSION` 临时改成该版本号再起一次即可（用完可以改回 `latest`）。

## 已知问题（已修复）

`docker-compose.yml` 里 `plex` 服务引用了未定义的 `PLEX_STORAGE_PATH`，会导致**任何**
compose 命令解析整个文件时报 `invalid spec: :/data:shared: empty section between colons`。
已在 `../.env` 补上 `PLEX_STORAGE_PATH=./plex/data` 修复。

## 为什么直接写进 docker-compose.yml

按当前约定直接写进 laradock 的 `docker-compose.yml`，好处是 `docker compose ps/logs` 不用带额外 `-f`；
代价是 laradock 上游更新时该文件可能冲突，合并时注意保留 `### New API ###` 这一段。
