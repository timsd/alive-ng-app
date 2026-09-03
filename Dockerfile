# syntax=docker/dockerfile:1

FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Public Flutter web configuration only. Do not put server/API secrets here.
ARG FLUTTER_BUILD_ARGS=""
# Optional cache-busting arg; set to a timestamp in Coolify to force a fresh build.
ARG BUILD_ID=""

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
RUN echo "Build ID: ${BUILD_ID}"
RUN flutter clean
RUN flutter config --enable-web \
    && dart scripts/configure_web.dart \
    && flutter build web --release --no-wasm-dry-run ${FLUTTER_BUILD_ARGS}

FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -q --spider http://127.0.0.1/ || exit 1
CMD ["nginx", "-g", "daemon off;"]
