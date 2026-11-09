# BuildKit/buildx sets this on its own; with the classic builder pass it:
#   docker build --build-arg BUILDPLATFORM=linux/amd64 .
ARG BUILDPLATFORM

# --- build: dependencies, web UI and server bundle ---
# Always runs on the builder's own architecture: the output (dist/) is plain
# JavaScript, identical for amd64 and arm64, so there is nothing to emulate.
FROM --platform=$BUILDPLATFORM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

# --- runtime: only dist/ (server.mjs + web/), no node_modules ---
FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build /app/dist ./
EXPOSE 8082
USER node
CMD ["node", "server.mjs"]
