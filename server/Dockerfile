# Serveur Resolio : PocketBase (base de données + comptes + API) dans un conteneur.
FROM alpine:3.22

ARG PB_VERSION=0.40.6
# Fourni automatiquement par Docker : amd64 (PC, la plupart des serveurs) ou arm64 (Raspberry Pi, serveurs ARM)
ARG TARGETARCH=amd64

RUN apk add --no-cache ca-certificates unzip wget tzdata \
 && wget -q "https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_${TARGETARCH}.zip" -O /tmp/pb.zip \
 && unzip -q /tmp/pb.zip pocketbase -d /pb \
 && rm /tmp/pb.zip \
 && chmod +x /pb/pocketbase

# Le schéma de la base (versionné dans Git) est appliqué automatiquement au démarrage.
COPY pb_migrations /pb/pb_migrations

ENV TZ=Europe/Paris
WORKDIR /pb
EXPOSE 8090

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD wget -q --spider http://127.0.0.1:8090/api/health || exit 1

CMD ["/pb/pocketbase", "serve", "--http=0.0.0.0:8090", "--dir=/pb/pb_data", "--migrationsDir=/pb/pb_migrations"]
