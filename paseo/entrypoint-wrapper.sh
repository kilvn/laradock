#!/bin/sh
# paseo entrypoint wrapper：先修工作区属主，再转交官方入口。
# 容器内 daemon/agent 以 paseo 用户（uid/gid 1000:1000）运行，
# Linux bind 挂载的工作区若属主不对会 permission denied，这里开机自动修正。
# 只修正 /workspace 顶层：daemon/agent 新建文件继承父目录属主，已够用；
# 全量 -R 在 Windows 挂载上会卡死（逐文件 Round-trip），在巨型工作区上也慢，故不用。
# PASEO_CHOWN_WORKSPACE=0 可强制跳过。
if [ "${PASEO_CHOWN_WORKSPACE:-1}" != "0" ] && [ -d /workspace ]; then
  OWNER="$(stat -c %u /workspace 2>/dev/null || echo skip)"
  if [ "$OWNER" != "1000" ] && [ "$OWNER" != "skip" ]; then
    echo "[entrypoint] chown 1000:1000 /workspace ..."
    chown 1000:1000 /workspace 2>/dev/null \
      && echo "[entrypoint] chown 完成" \
      || echo "[entrypoint] chown 失败（可能是 Windows 挂载），继续启动"
  fi
fi
exec /usr/bin/tini -- /usr/local/bin/paseo-docker-entrypoint "$@"
