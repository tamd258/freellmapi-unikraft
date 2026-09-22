# syntax=docker/dockerfile:1.7
# Unikraft 友好版：Alpine(musl) 构建 + FROM scratch 收尾
# （照 Unikraft 官方 Node 指南的做法：只拷 node 二进制、依赖库、CA 证书、应用）
ARG NODE_IMAGE=node:22-alpine

FROM ${NODE_IMAGE} AS deps
WORKDIR /app
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

FROM ${NODE_IMAGE} AS nodedist

FROM scratch
COPY --from=nodedist /usr/local/bin/node /usr/local/bin/node
COPY --from=nodedist /lib/ld-musl-x86_64.so.1 /lib/ld-musl-x86_64.so.1
COPY --from=nodedist /usr/lib/libgcc_s.so.1 /usr/lib/libgcc_s.so.1
COPY --from=nodedist /usr/lib/libstdc++.so.6 /usr/lib/libstdc++.so.6
COPY --from=nodedist /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=nodedist /etc/passwd /etc/passwd
COPY --from=nodedist /etc/group /etc/group
COPY --from=nodedist /etc/nsswitch.conf /etc/nsswitch.conf
COPY --from=nodedist /etc/hosts /etc/hosts
COPY --from=nodedist /etc/resolv.conf /etc/resolv.conf
COPY --from=build /app /app
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3001
ENV HOST=0.0.0.0
ENV FREELLMAPI_INSTALL_METHOD=unikraft
EXPOSE 3001
CMD ["/usr/local/bin/node", "/app/server/dist/index.js"]
