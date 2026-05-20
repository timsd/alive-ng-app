# syntax=docker/dockerfile:1

FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app
ARG FLUTTER_BUILD_ARGS=""
ARG FIREBASE_API_KEY=""
ARG FIREBASE_AUTH_DOMAIN=""
ARG FIREBASE_PROJECT_ID=""
ARG FIREBASE_STORAGE_BUCKET=""
ARG FIREBASE_MESSAGING_SENDER_ID=""
ARG FIREBASE_APP_ID=""
ARG FIREBASE_MEASUREMENT_ID=""
ARG FIREBASE_WEB_API_KEY=""
ARG FIREBASE_WEB_AUTH_DOMAIN=""
ARG FIREBASE_WEB_PROJECT_ID=""
ARG FIREBASE_WEB_STORAGE_BUCKET=""
ARG FIREBASE_WEB_MESSAGING_SENDER_ID=""
ARG FIREBASE_WEB_APP_ID=""
ARG FIREBASE_WEB_MEASUREMENT_ID=""
ARG RECAPTCHA_SITE_KEY=""

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
RUN flutter config --enable-web \
    && dart scripts/configure_web.dart \
    && flutter build web --release --no-wasm-dry-run $FLUTTER_BUILD_ARGS

FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
