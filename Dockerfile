# syntax=docker/dockerfile:1.7
# Unikraft 友好版：Alpine(musl) 基础 + 独立 runtime 阶段（不用 Debian/glibc）
ARG NODE_IMAGE=node:22-alpine

FROM ${NODE_IMAGE} AS deps
WORKDIR /app
# better-sqlite3 是原生模块，musl 上没有预编译产物，需要现场编译
RUN apk add --no-cache python3 make g++
COPY package.json package-lock.json ./
COPY shared/package.json ./shared/
COPY server/package.json ./server/
COPY client/package.json ./client/
COPY cli/package.json ./cli/
RUN npm ci

FROM deps AS build
WORKDIR /app
COPY . .
RUN npm run build && npm prune --omit=dev

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
RUN mkdir -p /app/server/data && chmod 777 /app/server/data
EXPOSE 3001
CMD ["/usr/local/bin/node", "/app/server/dist/index.js"]
