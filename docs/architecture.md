# Architecture diagram

```mermaid
flowchart LR
  client[Client] -->|HTTPS| nginx[NGINX]
  nginx --> app[FastAPI]
  app --> db[(PostgreSQL)]
  app --> redis[(Redis)]
```
