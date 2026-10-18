# syntax=docker/dockerfile:1

FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Public Flutter web configuration only. Do not put server/API secrets here.
ARG FLUTTER_BUILD_ARGS=""
ARG BUILD_ID=""

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
RUN echo "Build ID: ${BUILD_ID}"
ENV DART_VM_OPTIONS="--old_gen_heap_size=2048"
RUN flutter config --enable-web \
    && dart scripts/configure_web.dart \
    && nice -n 19 flutter build web --release --no-wasm-dry-run --no-source-maps --dart2js-optimization=O1 ${FLUTTER_BUILD_ARGS}

FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -q --spider http://127.0.0.1/ || exit 1
CMD ["nginx", "-g", "daemon off;"]
