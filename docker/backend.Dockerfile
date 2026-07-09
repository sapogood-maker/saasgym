# syntax=docker/dockerfile:1

# Imagens-base fixadas por digest para builds reproduzíveis (o conteúdo por
# trás de uma tag como "node:22-alpine" pode mudar quando a distro publica
# uma nova patch release). Para atualizar deliberadamente:
#   docker manifest inspect node:22-alpine -v | grep digest
FROM node:22-alpine@sha256:16e22a550f3863206a3f701448c45f7912c6896a62de43add43bb9c86130c3e2 AS base
# node:22-alpine não traz o pacote "openssl" — sem ele o Prisma não consegue
# detectar a versão do OpenSSL do sistema e escolhe o engine errado (ver
# binaryTargets em prisma/schema.prisma).
RUN apk add --no-cache openssl=3.5.7-r0
WORKDIR /app
COPY backend/package*.json ./
COPY backend/prisma ./prisma

FROM base AS deps
# "npm ci" já dispara "prisma generate" sozinho via postinstall do
# @prisma/client (o schema já está copiado acima) — não precisa de um RUN
# separado aqui.
RUN npm ci

FROM deps AS build
COPY backend ./
RUN npm run build

FROM node:22-alpine@sha256:16e22a550f3863206a3f701448c45f7912c6896a62de43add43bb9c86130c3e2 AS production
RUN apk add --no-cache openssl=3.5.7-r0
WORKDIR /app
ENV NODE_ENV=production
RUN chown node:node /app
# Pré-cria o mount point do volume de uploads com o dono certo — um volume
# nomeado novo herda permissão/conteúdo do diretório da imagem na primeira
# vez que é montado; sem isso, o Docker cria o mount point como root e o
# processo (rodando como "node", não-root) não consegue escrever nele.
RUN mkdir -p /app/uploads && chown node:node /app/uploads
COPY --chown=node:node backend/package*.json ./
COPY --chown=node:node backend/prisma ./prisma
USER node
# idem: "npm ci" já gera o Prisma Client via postinstall.
RUN npm ci --omit=dev && npm cache clean --force
COPY --chown=node:node --from=build /app/dist ./dist

EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/api/health || exit 1

CMD ["sh", "-c", "npx prisma migrate deploy && node dist/prisma/seed.js && node dist/main"]
