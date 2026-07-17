FROM node:24-bookworm-slim AS build

WORKDIR /src
COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM nginx:1.29-alpine AS runtime

RUN apk add --no-cache nodejs
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/dist /usr/share/nginx/html
COPY tools/healthcheck.js /healthcheck.js
RUN touch /var/run/nginx.pid \
  && chown -R nginx:nginx /var/cache/nginx /var/run/nginx.pid /usr/share/nginx/html /healthcheck.js

USER nginx
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=5 CMD ["node", "/healthcheck.js"]
EXPOSE 8080
