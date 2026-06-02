FROM redis:7.2-alpine

# Patch Alpine packages in the base image (Trivy / supply-chain hygiene).
RUN apk update && apk upgrade --no-cache

# Minimal redis-cart image scaffold for Phase 5 bring-up.
EXPOSE 6379

CMD ["redis-server", "--save", "", "--appendonly", "no"]
