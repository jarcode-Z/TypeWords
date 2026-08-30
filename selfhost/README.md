# Self-host assets

词库与脚本镜像目录。**完整部署步骤（中文）请看：**

→ [docs/DEPLOY-SELFHOST.md](../docs/DEPLOY-SELFHOST.md)

## Quick commands

```bash
./scripts/sync-selfhost-assets.sh      # pull into selfhost/
./scripts/setup-local-assets.sh        # symlink into apps/nuxt/public for local dev
pnpm run docker-build                  # build frontend → apps/nuxt/.output/public

# Upload (example web root)
rsync -avz --exclude files --exclude libs apps/nuxt/.output/public/ root@HOST:/var/www/TypeWords/public/
rsync -avz selfhost/files/ root@HOST:/var/www/TypeWords/public/files/
rsync -avz selfhost/libs/  root@HOST:/var/www/TypeWords/public/libs/
```

Do **not** zip/upload `apps/nuxt/public/files` if it is a symlink — zip `selfhost/files` instead.
