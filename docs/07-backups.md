# Backups

> Módulo `backup` ainda não implementado (ver `docs/08-roadmap.md`). Este documento define a arquitetura desde já. A interface `StorageProvider` que este módulo vai usar já existe, implementada no Sprint 2 (`backend/src/storage/`, ver `docs/13-admin-saas.md`) — falta escrever `GoogleDriveStorageProvider` (ou o provider decidido) e o módulo `backup` em si.

## Fluxo

```
PostgreSQL → pg_dump → ZIP → StorageProvider (Google Drive na primeira versão)
```

## Por que uma abstração de storage, e não "integração com Google Drive"

A lógica de backup **nunca** deve conhecer detalhes do Google Drive diretamente. Todo o módulo `backup` fala com a interface `StorageProvider`:

```
upload(file, path)
download(path)
delete(path)
getSignedUrl(path)
```

A primeira implementação é `GoogleDriveStorageProvider`. Trocar ou adicionar um destino (OneDrive, Dropbox, Amazon S3, Cloudflare R2, Backblaze) significa escrever uma nova classe que implementa `StorageProvider` — nenhuma mudança no módulo `backup` em si. Essa é a mesma abstração usada para uploads de arquivos do usuário (fotos, vídeos de treino) — ver `docs/01-arquitetura.md`.

## Modelagem

- `BackupJob` — histórico de execuções: tipo (manual/automático), provider usado, status, nome do arquivo, tamanho, erro (se houver), quem iniciou.
- `BackupConfig` — qual provider e credenciais estão ativos. É configuração de sistema (`SYSTEM_ADMIN`), não por academia — o backup opera sobre o banco inteiro (todas as academias), não é uma entidade tenant-scoped.

## Escopo por versão

| Fase | Entrega |
|---|---|
| Sprint do módulo `backup` (ver `docs/08-roadmap.md`) | Backup **manual** via endpoint, execução do fluxo completo (`pg_dump` → zip → Google Drive), histórico consultável. |
| Futuro | Backup **automático** agendado, **download** direto pela UI, **restauração** guiada, múltiplos providers ativos simultaneamente. |

## Segurança

Credenciais de provider (tokens OAuth do Google Drive, chaves de API de S3/R2) ficam criptografadas em repouso e nunca são expostas em respostas de API — apenas o `BackupConfig.provider` (qual está ativo) é visível na UI.
