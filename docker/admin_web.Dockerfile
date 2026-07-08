# syntax=docker/dockerfile:1

# Imagens-base fixadas por digest para builds reproduzíveis — ver
# docker/backend.Dockerfile para como atualizar deliberadamente.
# Build: usa a imagem oficial da comunidade com o Flutter SDK pré-instalado.
FROM ghcr.io/cirruslabs/flutter:3.41.1@sha256:599511dae9e25f068c466f637f6f3dc038a3f6cbffd378057ef93d0c409b1369 AS build
WORKDIR /workspace

# O admin_web depende de packages/shared_core via Dart pub workspace, então o
# contexto de build precisa do monorepo inteiro (ver docker-compose.yml: build.context = raiz).
#
# Copia só os pubspec.yaml primeiro para que `flutter pub get` (rede) fique em
# uma camada cacheada e só seja refeito quando uma dependência mudar — não a
# cada alteração de código Dart.
COPY pubspec.yaml ./
COPY admin_web/pubspec.yaml ./admin_web/pubspec.yaml
COPY student_web/pubspec.yaml ./student_web/pubspec.yaml
COPY packages/shared_core/pubspec.yaml ./packages/shared_core/pubspec.yaml
RUN flutter pub get

COPY admin_web ./admin_web
COPY student_web ./student_web
COPY packages ./packages

WORKDIR /workspace/admin_web
RUN flutter build web --release --no-wasm-dry-run

FROM nginx:1.27-alpine@sha256:65645c7bb6a0661892a8b03b89d0743208a18dd2f3f17a54ef4b76fb8e2f2a10 AS production
COPY docker/nginx/spa.conf /etc/nginx/conf.d/default.conf
COPY --from=build /workspace/admin_web/build/web /usr/share/nginx/html

EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1/ || exit 1
