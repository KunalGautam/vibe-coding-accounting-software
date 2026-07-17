FROM golang:1.23-bookworm AS build

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=1 GOOS=linux go build -o /out/api ./cmd/api
RUN CGO_ENABLED=1 GOOS=linux go build -o /out/worker ./cmd/worker
RUN CGO_ENABLED=1 GOOS=linux go build -o /out/migrate ./cmd/migrate
RUN CGO_ENABLED=1 GOOS=linux go build -o /out/restore ./cmd/restore
RUN CGO_ENABLED=0 GOOS=linux go build -o /out/healthcheck ./cmd/healthcheck

FROM debian:bookworm-slim AS runtime

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates tzdata \
  && groupadd --system accounting \
  && useradd --system --gid accounting --home-dir /app --shell /usr/sbin/nologin accounting \
  && mkdir -p /app/storage \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /out/api /app/api
COPY --from=build /out/worker /app/worker
COPY --from=build /out/migrate /app/migrate
COPY --from=build /out/restore /app/restore
COPY --from=build /out/healthcheck /app/healthcheck

RUN chown -R accounting:accounting /app

ENV API_ADDR=:8080
EXPOSE 8080

USER accounting
CMD ["/app/api"]
