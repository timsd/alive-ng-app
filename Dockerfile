# syntax=docker/dockerfile:1

# Switch to a lightweight web-focused Flutter image
FROM plugaglobal/flutter:3.22.0 AS build

WORKDIR /app

# Build Arguments
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

# Cache dependencies layer
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy source and build web release
COPY . .
RUN flutter config --enable-web \
    && dart scripts/configure_web.dart \
    && flutter build web --release $FLUTTER_BUILD_ARGS

# Stage 2: Web Server
FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]