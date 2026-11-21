# BuildKit/buildx sets this on its own; with the classic builder pass it:
#   docker build --build-arg BUILDPLATFORM=linux/amd64 .
ARG BUILDPLATFORM

# --- build: Flutter web app and server bundle ---
# Always runs on the builder's own architecture: the output (dist/) is plain
# JavaScript, Wasm and assets, identical for amd64 and arm64, so there is
# nothing to emulate. Debian (glibc) rather than Alpine: the Flutter SDK
# needs it.
FROM --platform=$BUILDPLATFORM node:22-bookworm-slim AS build

# the Flutter release the app is built and tested with (same as CI)
ARG FLUTTER_VERSION=3.47.5
RUN apt-get update \
 && apt-get install -y --no-install-recommends git curl ca-certificates unzip xz-utils \
 && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git /opt/flutter
ENV PATH="/opt/flutter/bin:$PATH" \
    FLUTTER_SUPPRESS_ANALYTICS=true \
    CI=true
RUN flutter config --no-analytics --no-cli-animations \
 && flutter precache --web

WORKDIR /app
# dependencies first, so they stay cached while the code changes
COPY package.json package-lock.json ./
RUN npm ci
COPY app/pubspec.yaml app/pubspec.lock app/
RUN cd app && flutter pub get
COPY . .
# web app (version from package.json) + single-file server → dist/
RUN npm run build

# --- runtime: only dist/ (server.mjs + web/), no node_modules, no Flutter ---
FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build /app/dist ./
EXPOSE 8082
# No `USER node` here: ZeroTier writes /var/lib/zerotier-one/authtoken.secret
# as root:root 0600, so a non-root process cannot read it from the mounted
# volume. The server starts as root only to read that token and to fix the
# ownership of /data (root-owned on existing volumes), then drops to uid/gid
# 1000 (`node`) by itself, before serving anything (server/src/privileges.ts).
CMD ["node", "server.mjs"]
