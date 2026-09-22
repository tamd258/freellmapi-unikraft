# freellmapi-unikraft

把 [FreeLLMAPI](https://github.com/tashfeenahmed/freellmapi) 打包成 Unikraft Cloud 能跑的镜像。

**为什么需要它**：上游官方镜像基于 `node:20-bookworm-slim`（Debian/glibc）+ `docker-entrypoint.sh`，
在 Unikraft 的 `base-compat` 运行时上启动 3.8 秒即静默退出（日志为空）。Unikraft 官方 Node 指南
刻意用 **Alpine(musl)** 基础镜像，所以这里改用 `node:22-alpine` 重打包。

**产物**：`ghcr.io/tamd258/freellmapi-unikraft:latest`（linux/amd64）

**触发**：Actions → build-unikraft-image → Run workflow

构建时始终 `git clone` 上游最新代码，所以每次跑都能拿到最新版本。
