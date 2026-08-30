# 独立部署说明（Nginx 静态站）

本文记录本仓库的**自托管**部署方式：不依赖 `*.typewords.cc`，词库与脚本走同源 `/files/`、`/libs/`。

当前线上示例路径：

- 网站根目录：`/var/www/TypeWords/public`
- 访问地址：`http://公网IP/`

## 架构

```text
浏览器
  ├─ /              → 前端（nuxt generate 产物）
  ├─ /files/        → 词库列表、dicts、音效（来自 selfhost/files）
  └─ /libs/         → JSZip / XLSX / Shepherd / snapdom（来自 selfhost/libs）
```

代码里配置见 `packages/core/src/config/env.ts`：

- `RESOURCE_URL = '/files/'`
- `LIBS_URL = '/libs/'`

## 本机准备（一次性 / 资源更新时）

```bash
cd /path/to/TypeWords

# 1) 从官方 CDN 同步资源到 selfhost/（体积约数百 MB，勿提交 git）
chmod +x scripts/sync-selfhost-assets.sh scripts/setup-local-assets.sh
./scripts/sync-selfhost-assets.sh

# 2) 本地开发：把 selfhost 链到 apps/nuxt/public
./scripts/setup-local-assets.sh
pnpm run dev
# 自检：http://localhost:5567/files/list/word.json
```

> `apps/nuxt/public/files`、`libs` 是**软链**，指向 `selfhost/`。  
> 打包产物 `.output/public` 里的 `files`/`libs` 往往也是软链，**不能**只传软链到服务器。

## 构建前端

在内存充足的本机执行（小规格 ECS 上 `nuxt generate` 易 OOM）：

```bash
pnpm install
pnpm run docker-build
# 产物：apps/nuxt/.output/public/
```

可选：构建时写入站点 Origin（SEO）

```bash
ORIGIN=http://你的公网IP pnpm run docker-build
```

## 上传到服务器（推荐流程）

假设服务器网站根为 `/var/www/TypeWords/public`。

### 1. 上传前端

```bash
rsync -avz --delete \
  apps/nuxt/.output/public/ \
  root@服务器IP:/var/www/TypeWords/public/
```

若用面板/FTP：上传 `.output/public` 内文件到该目录即可。  
`--delete` 会删掉服务器上多余文件；若担心误删 `files`/`libs`，可先上传前端、再单独传资源，或 rsync 时排除：

```bash
rsync -avz --delete \
  --exclude files --exclude libs \
  apps/nuxt/.output/public/ \
  root@服务器IP:/var/www/TypeWords/public/
```

### 2. 上传词库与脚本（必须是实体文件）

**正确来源：`selfhost/files`、`selfhost/libs`（不要 zip `apps/nuxt/public/files` 软链）。**

```bash
rsync -avz selfhost/files/ root@服务器IP:/var/www/TypeWords/public/files/
rsync -avz selfhost/libs/  root@服务器IP:/var/www/TypeWords/public/libs/
```

用 zip 时：

```bash
cd selfhost
zip -r ~/Desktop/files.zip files
zip -r ~/Desktop/libs.zip libs
# 传到服务器后解压到 public/files、public/libs
```

解压后服务器上应为**真实目录**，例如：

```text
/var/www/TypeWords/public/
  index.html
  _nuxt/
  200.html
  files/
    list/word.json
    dicts/
    sound/
  libs/
    Shepherd.14.5.1.mjs.js
    jszip.min.js
    xlsx.full.min.js
    snapdom.min.js
```

若提示「解压结果是符号链接」→ 说明压错了软链，删掉后按上面重新打实体包。

```bash
ls -la /var/www/TypeWords/public/files /var/www/TypeWords/public/libs
# 应为 drwx...，不应是 lrwx... -> ../../../selfhost/...
```

## Nginx 配置

`root` 指向 `/var/www/TypeWords/public`，并保证 `/files/`、`/libs/` **不会**落入 SPA 回退：

```nginx
server {
    listen 80;
    server_name _;
    root /var/www/TypeWords/public;
    index index.html;

    location ^~ /files/ {
        try_files $uri $uri/ =404;
    }

    location ^~ /libs/ {
        try_files $uri $uri/ =404;
    }

    location / {
        try_files $uri $uri/ /200.html;
    }
}
```

可参考仓库根目录 `nginx.static.conf`。改完后：

```bash
nginx -t && nginx -s reload
```

## 验收

```bash
curl -sI http://127.0.0.1/files/list/word.json
# 期望：200，Content-Type: application/json

curl -sI http://127.0.0.1/libs/Shepherd.14.5.1.mjs.js
# 期望：200，Content-Type: application/javascript（或 text/javascript）
```

浏览器强制刷新后检查：

- [ ] 词库列表能加载
- [ ] 「开始学习」不再一直 loading
- [ ] 导入导出正常（依赖 `/libs`）
- [ ] DevTools 无 `*.typewords.cc` 请求（有道发音除外）

## 常见问题

| 现象 | 原因 | 处理 |
|------|------|------|
| 开始学习一直转圈；JSON 报 `Unexpected token '<'` | `/files/` 返回了 HTML | 补传实体 `files/`，检查 Nginx `location ^~ /files/` |
| Shepherd 加载失败，MIME 为 text/html | `/libs/` 不存在或被 SPA 回退 | 补传实体 `libs/`，检查 `location ^~ /libs/` |
| 解压出来是软链 | zip 打的是 `public/files` 软链 | 改为打包 `selfhost/files` |
| 服务器上 `nuxt generate` OOM | 内存不够 | 只在本机构建再上传 |
| 本地 dev 缺 `/files` | 未建软链 | `./scripts/setup-local-assets.sh` |

## 已知第三方

单词发音仍使用有道：`https://dict.youdao.com/dictvoice?...`（未自建 TTS）。

## 相关文件

- `packages/core/src/config/env.ts` — 资源 URL
- `scripts/sync-selfhost-assets.sh` — 同步 CDN 资源
- `scripts/setup-local-assets.sh` — 本地软链
- `nginx.static.conf` — Nginx 参考配置
- `Dockerfile.static` — 可选：打成含 files/libs 的 Nginx 镜像
- `selfhost/` — 资源目录（大文件默认 gitignore）
