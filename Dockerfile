# Build stage: compile the NestJS app using a deterministic dependency install.
FROM node:20-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY tsconfig.json tsconfig.build.json nest-cli.json jest.config.ts ./
COPY src ./src
RUN npm run build

# Runtime stage: keep the final image smaller and production-oriented.
FROM node:20-alpine AS runtime
WORKDIR /app
ARG BUILD_ID=local
ARG SOURCE_COMMIT=local
ENV NODE_ENV=production \
    APP_NAME=nest-hello-release-demo \
    BUILD_ID=${BUILD_ID} \
    SOURCE_COMMIT=${SOURCE_COMMIT}
LABEL org.opencontainers.image.title="nest-hello-release-demo" \
      org.opencontainers.image.version="${BUILD_ID}" \
      org.opencontainers.image.revision="${SOURCE_COMMIT}"
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY --from=build /app/dist ./dist
EXPOSE 3000
# The container health check keeps deployment validation close to the runtime boundary.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health/live >/dev/null || exit 1
CMD ["node", "dist/main.js"]
