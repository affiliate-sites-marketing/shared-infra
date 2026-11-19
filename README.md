# Shared Infra (`shared-minio` + `shared-nginx`)

Hạ tầng dùng chung cho cả 2 website:
- **`heygoodly`** (`:80` / `heygoodly.localhost`) $\rightarrow$ bucket `heygoodly-media`
- **`heyworthly`** (`:81` / `heyworthly.localhost` / `heyworthly.com`) $\rightarrow$ bucket `heyworthly-media`

## Khởi động ở Local
```bash
cd /Users/khoinguyen/Documents/affiliate-sites-marketing/shared-infra
./scripts/up-shared.sh
```
MinIO Console: http://localhost:9001 (`minioadmin` / `MySecret99#Minio`)
