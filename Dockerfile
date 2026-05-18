# syntax=docker/dockerfile:1

FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app
ARG FLUTTER_BUILD_ARGS=""

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
RUN flutter config --enable-web \
    && echo "Flutter build args: $FLUTTER_BUILD_ARGS" \
    && flutter build web --release --no-wasm-dry-run $FLUTTER_BUILD_ARGS

FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
