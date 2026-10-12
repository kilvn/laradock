FROM ghcr.io/getpaseo/paseo:latest

# 构建期代理，仅慢速/受限网络需要；默认空=直连。compose 透传 PASEO_BUILD_PROXY
ARG BUILD_PROXY
# npm 安装源；默认空=官方源。compose 透传 PASEO_NPM_REGISTRY
ARG NPM_REGISTRY

USER root

# agy headless 认证前置：仅设 GEMINI_API_KEY 不生效，
# 必须同时存在该配置文件（API key 仍由运行期环境变量提供）
RUN mkdir -p /home/paseo/.gemini/antigravity-cli \
    && echo '{"modelProvider": "gemini"}' > /home/paseo/.gemini/antigravity-cli/settings.json \
    && chown -R 1000:1000 /home/paseo/.gemini

RUN echo "[1/5] 安装基础工具 ..." \
    && (command -v curl >/dev/null 2>&1 || apt-get update) \
    && (command -v curl >/dev/null 2>&1 || apt-get install -y --no-install-recommends curl) \
    && (command -v tar >/dev/null 2>&1 || apt-get install -y --no-install-recommends tar)

RUN echo "[2/5] 安装官方二进制安装器提供的 agent CLI ..." \
    && curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path \
    && cp /home/paseo/.opencode/bin/opencode /usr/local/bin/opencode \
    && curl -fsSL https://claude.ai/install.sh | bash \
    && cp -L /home/paseo/.local/bin/claude /usr/local/bin/claude \
    && curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_INSTALL_DIR=/usr/local/bin CODEX_NON_INTERACTIVE=1 sh \
    && curl -fsSL https://gh.io/copilot-install | PREFIX=/usr/local bash

RUN echo "[3/5] 安装 Antigravity CLI (agy) ..." \
    && PROXY_ENV="${BUILD_PROXY:+HTTP_PROXY=$BUILD_PROXY HTTPS_PROXY=$BUILD_PROXY}" \
    && env $PROXY_ENV curl -fsSL https://antigravity.google/cli/install.sh -o /tmp/agy-install.sh \
    && env $PROXY_ENV bash /tmp/agy-install.sh --dir /usr/local/bin \
    && rm -f /tmp/agy-install.sh \
    && agy --version

RUN echo "[4/5] 安装仅提供 npm 渠道的 agent CLI ..." \
    && npm install -g ${NPM_REGISTRY:+--registry=$NPM_REGISTRY} --ignore-scripts @earendil-works/pi-coding-agent \
    && npm install -g ${NPM_REGISTRY:+--registry=$NPM_REGISTRY} @google/gemini-cli

RUN echo "[5/5] 验证 CLI 与 agy 配置 ..." \
    && for cli in opencode claude codex copilot agy pi gemini; do \
         command -v "$cli" || exit 1; \
       done \
    && grep -q gemini /home/paseo/.gemini/antigravity-cli/settings.json \
    && echo "[5/5] 全部就绪 ✓"

COPY entrypoint-wrapper.sh /usr/local/bin/paseo-entrypoint-wrapper.sh
RUN chmod +x /usr/local/bin/paseo-entrypoint-wrapper.sh

ENTRYPOINT ["/usr/local/bin/paseo-entrypoint-wrapper.sh"]
WORKDIR /workspace
