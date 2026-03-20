FROM mcr.microsoft.com/playwright:v1.52.0-jammy

WORKDIR /app
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

COPY clubspark-exporter/package.json ./
RUN npm install --omit=dev

COPY scripts/export-clubspark-contacts-local.mjs ./
COPY scripts/export-clubspark-members-local.mjs ./
COPY scripts/export-clubspark-auth-session-local.mjs ./
COPY scripts/clubspark-export-server.mjs ./

EXPOSE 3001
CMD ["node", "clubspark-export-server.mjs"]
