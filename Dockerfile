# syntax=docker/dockerfile:1

# Stage 1: Build Flutter Web using public image
FROM ghcr.io/instrumentisto/flutter:3.22.0 AS build

WORKDIR /app

# Declare all your build args
ARG FLUTTER_BUILD_ARGS=""
ARG COOLIFY_URL=""

# Cache dependencies
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy source and build
COPY . .
RUN flutter config --enable-web \
    && dart scripts/configure_web.dart \
    && flutter build web --release $FLUTTER_BUILD_ARGS

# Stage 2: Serve with Nginx
FROM nginx:1.27-alpine

# Copy your working Flutter Nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]