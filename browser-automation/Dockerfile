FROM mcr.microsoft.com/playwright:v1.58.2-noble

WORKDIR /app

ENV NODE_ENV=production
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
ENV EXPORTER_DEFAULT_SCRIPT_DIR=/app/default-scripts

COPY browser-automation/package.json ./
RUN npm install --omit=dev

COPY browser-automation/scripts ./scripts
COPY scripts ./default-scripts

EXPOSE 3000
CMD ["npm", "start"]
