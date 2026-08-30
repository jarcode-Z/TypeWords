import { existsSync, readFileSync } from 'fs'
import { resolve } from 'path'

export default defineEventHandler(() => {
  const candidates = [
    resolve(process.cwd(), 'selfhost/files/list/article.json'),
    resolve(process.cwd(), '../../selfhost/files/list/article.json'),
    resolve(process.cwd(), 'public/list/article.json'),
  ]
  for (const path of candidates) {
    if (existsSync(path)) {
      return JSON.parse(readFileSync(path, 'utf-8'))
    }
  }
  throw createError({
    statusCode: 404,
    statusMessage: 'article list not found; run scripts/sync-selfhost-assets.sh first',
  })
})
