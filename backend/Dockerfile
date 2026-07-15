FROM golang:1.23-bookworm AS build

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=1 GOOS=linux go build -o /out/api ./cmd/api
RUN CGO_ENABLED=1 GOOS=linux go build -o /out/worker ./cmd/worker
RUN CGO_ENABLED=1 GOOS=linux go build -o /out/migrate ./cmd/migrate
RUN CGO_ENABLED=1 GOOS=linux go build -o /out/restore ./cmd/restore

FROM debian:bookworm-slim AS runtime

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates tzdata \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /out/api /app/api
COPY --from=build /out/worker /app/worker
COPY --from=build /out/migrate /app/migrate
COPY --from=build /out/restore /app/restore

ENV API_ADDR=:8080
EXPOSE 8080

CMD ["/app/api"]
