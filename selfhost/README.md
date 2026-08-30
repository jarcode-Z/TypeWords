# Self-host independent deploy

This tree holds mirrored assets for same-origin `/files/` and `/libs/`.

## Layout

```
selfhost/
  files/          → served at http://公网IP/files/
  libs/           → served at http://公网IP/libs/
  README.md
```

Large dict/audio files are **not** committed. Pull them on your build machine:

```bash
chmod +x scripts/sync-selfhost-assets.sh
./scripts/sync-selfhost-assets.sh
# optional full dicts tree:
FULL=1 ./scripts/sync-selfhost-assets.sh
```

## Local development

After sync, link assets into Nuxt `public/` (required because `RESOURCE_URL=/files/`):

```bash
./scripts/setup-local-assets.sh
pnpm run dev
```

Check:

- http://localhost:5567/files/list/word.json
- http://localhost:5567/libs/Shepherd.14.5.1.mjs.js

## Nginx static deploy (no Docker)

```bash
pnpm run docker-build
./scripts/setup-local-assets.sh   # optional for local; deploy still needs real files/

# Upload site root = frontend + files + libs
rsync -avz --delete apps/nuxt/.output/public/ user@host:/WEBROOT/
# Follow symlinks so files/libs content is uploaded:
rsync -avz -L selfhost/files/ user@host:/WEBROOT/files/
rsync -avz -L selfhost/libs/  user@host:/WEBROOT/libs/
```

Nginx must include:

```nginx
location ^~ /files/ { try_files $uri $uri/ =404; }
location ^~ /libs/  { try_files $uri $uri/ =404; }
location / { try_files $uri $uri/ /200.html; }
```

## Docker image deploy

On a machine with enough RAM (not a 1–2G ECS):

```bash
# 1) frontend
pnpm install
pnpm run docker-build

# 2) assets
./scripts/sync-selfhost-assets.sh

# 3) image (linux/amd64 for Alibaba Cloud)
docker build --platform linux/amd64 -f Dockerfile.static -t typewords:local .
docker save typewords:local | gzip > typewords.tar.gz
scp typewords.tar.gz root@YOUR_PUBLIC_IP:/root/
```

> 注意：若 `/files/`、`/libs/` 返回 HTML 或按钮一直 loading，多半是镜像过旧或目录权限导致 nginx 读不到资源。请用**含 selfhost 的新镜像**重新 `load` 并替换容器。Dockerfile 已包含 `chmod -R a+rX`。

On the server:

```bash
gunzip -c /root/typewords.tar.gz | docker load
docker rm -f typewords 2>/dev/null
docker run -d --name typewords -p 80:80 --restart unless-stopped typewords:local
```

Open `http://YOUR_PUBLIC_IP` (security group: TCP 80).

Optional SEO origin when rebuilding the frontend:

```bash
ORIGIN=http://YOUR_PUBLIC_IP pnpm run docker-build
```

## Acceptance

- Word/article lists load
- Start practice works
- Import/export (needs `/libs` JSZip/XLSX)
- Keyboard sounds work
- DevTools: no requests to `*.typewords.cc` except optional Youdao TTS (`dict.youdao.com`)

## Remaining third-party

Word pronunciation still uses Youdao (`https://dict.youdao.com/dictvoice?...`). Replacing TTS is out of scope for this self-host pass.
