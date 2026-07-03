FROM ghcr.io/anomalyco/opencode:latest

RUN echo "[1/3] 安装 tmux、nodejs、npm ..." \
    && apk add --no-cache tmux nodejs npm \
    && echo "[1/3] 系统包安装完成 ✓"

RUN echo "[2/3] 安装 codegraph ..." \
    && npm i -g codegraph \
    && echo "[2/3] codegraph 安装完成 ✓"

RUN echo "[3/3] 验证安装 ..." \
    && echo "  tmux:   $(tmux -V)" \
    && echo "  node:   $(node -v)" \
    && echo "  npm:    $(npm -v)" \
    && echo "  codegraph: $(which codegraph)" \
    && echo "[3/3] 全部就绪 ✓"

WORKDIR /workspace

ENTRYPOINT ["opencode", "serve", "--mdns", "--port", "4096"]
