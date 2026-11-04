#!/usr/bin/env bash
# 把本地跑通的 magpie 配置迁到服务器
#
# 用法：
#   ./migrate-config.sh pack                       # 本地打包
#   scp magpie-config.tgz user@server:/tmp/        # 上传
#   ./migrate-config.sh unpack /tmp/magpie-config.tgz /opt/magpie/config   # 服务器上执行
#
# 打包内容：providers.json、plugin-auth.json、routing/、gateway 密钥、settings —— 全部在 /config 下。

set -euo pipefail

LOCAL_DATA="${LOCAL_DATA:-$HOME/.laradock/data/magpie}"

case "${1:-}" in
  pack)
    OUT="${2:-magpie-config.tgz}"
    tar czf "$OUT" -C "$(dirname "$LOCAL_DATA")" "$(basename "$LOCAL_DATA")"
    echo "✅ $OUT ($(du -h "$OUT" | cut -f1))"
    echo "   内容含所有上游凭证，传输时注意使用 scp/ssh，不要走公共网盘"
    ;;
  unpack)
    ARCHIVE="${2:?usage: $0 unpack <archive> <target-dir>}"
    TARGET="${3:?usage: $0 unpack <archive> <target-dir>}"
    mkdir -p "$TARGET"
    tar xzf "$ARCHIVE" -C "$(dirname "$TARGET")"
    # 镜像里 magpie 以 uid 65532 运行，必须能写这个目录
    sudo chown -R 65532:65532 "$TARGET"
    echo "✅ 已解压到 $TARGET，属主 65532:65532"
    ;;
  *)
    sed -n '2,10p' "$0"
    exit 2
    ;;
esac
