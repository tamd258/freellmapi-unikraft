# syntax=docker/dockerfile:1.7
# 关键修正：Unikraft base-compat 是 glibc 运行时，必须用 glibc 基础镜像构建原生模块
# （better-sqlite3）。原先 node:22-alpine(musl) 编出的 .node 在 unikernel 里 dlopen 失败 -> exit 1。
ARG NODE_IMAGE=node:22-bookworm-slim

FROM ${NODE_IMAGE} AS deps
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends python3 make g++ \
    && rm -rf /var/lib/apt/lists/*
COPY package.json package-lock.json ./
COPY shared/package.json ./shared/
COPY server/package.json ./server/
COPY client/package.json ./client/
COPY cli/package.json ./cli/
# sharp 必须保留：构建期 tsc 要它的类型声明，删了会 TS2307 编译失败。
# 运行时用 try/catch 动态 import 优雅降级（缺 sharp 原图直传），所以在 build 阶段结束后再删。
RUN npm install --no-audit --no-fund

FROM deps AS build
WORKDIR /app
COPY . .
RUN npm run build
# 构建完再把 sharp 原生模块从 node_modules 拿掉（省 ~50MiB libvips，运行时不需要）
RUN rm -rf /app/node_modules/sharp /app/server/node_modules/sharp 2>/dev/null || true
# 瘦身：client/cli 只是构建期产物（依赖被 npm workspaces hoist 进 root node_modules，
# 会整包打进 unikraft initrd 导致 600MiB+ 单 PUT 超时）。构建完把 client/cli 移出 workspaces 再 prune。
RUN node -e "const f='package.json';const p=require('./'+f);p.workspaces=(p.workspaces||[]).filter(w=>!['client','cli'].includes(w));require('fs').writeFileSync(f,JSON.stringify(p,null,2))"
RUN npm prune --omit=dev --workspaces=false || npm prune --omit=dev
# 兜底：显式清掉 client 运行时大依赖（防止 prune 因 hoist 残留）
RUN rm -rf /app/node_modules/react /app/node_modules/react-dom /app/node_modules/recharts \
  /app/node_modules/@tanstack /app/node_modules/lucide-react /app/node_modules/react-markdown \
  /app/node_modules/remark-gfm /app/node_modules/@dnd-kit /app/node_modules/@base-ui \
  /app/node_modules/tailwindcss /app/node_modules/@tailwindcss /app/node_modules/highlight.js \
  /app/node_modules/simple-icons /app/node_modules/shadcn /app/node_modules/clsx \
  /app/node_modules/tailwind-merge /app/node_modules/class-variance-authority \
  /app/node_modules/@fontsource-variable /app/node_modules/liquid-gooey /app/node_modules/react-router-dom \
  /app/node_modules/tw-animate-css /app/node_modules/@freellmapi/client 2>/dev/null || true

FROM ${NODE_IMAGE} AS runtime
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3001
ENV HOST=0.0.0.0
ENV FREELLMAPI_INSTALL_METHOD=unikraft
COPY --from=build /app/package.json /app/package-lock.json ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/server/node_modules ./server/node_modules
COPY --from=build /app/shared ./shared
COPY --from=build /app/server/package.json ./server/package.json
COPY --from=build /app/desktop/package.json ./desktop/package.json
COPY --from=build /app/server/dist ./server/dist
COPY --from=build /app/client/dist ./client/dist
# 诊断：打印各层体积，确认 initrd 是否仍过大导致 unikraft 单 PUT 超时
RUN echo "=== rootfs size ===" && du -sh / 2>/dev/null; du -sh /app 2>/dev/null; du -sh /usr/local 2>/dev/null; du -sh /usr/local/bin/node 2>/dev/null; du -sh /app/node_modules 2>/dev/null; du -sh /app/server/node_modules 2>/dev/null
RUN mkdir -p /app/server/data
# 关键：清掉 node 基础镜像自带的 docker-entrypoint.sh，直接用绝对路径启动
ENTRYPOINT []
EXPOSE 3001
CMD ["/usr/local/bin/node", "/app/server/dist/index.js"]
