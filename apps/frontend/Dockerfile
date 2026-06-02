FROM nginx:1.27-alpine

# Placeholder image until frontend source is added. Bake config at build time so the
# container can run as the unprivileged nginx user (Pod Security restricted-friendly).
# apk upgrade: base tag lags patched Alpine packages; keeps Trivy HIGH/CRITICAL gate green.
RUN apk update && apk upgrade --no-cache \
  && mkdir -p /usr/share/nginx/html \
  && printf '%s\n' '<!doctype html><html><body><h1>frontend scaffold</h1></body></html>' > /usr/share/nginx/html/index.html \
  && sed -i 's/listen       80;/listen       8080;/' /etc/nginx/conf.d/default.conf \
  && chown -R nginx:nginx /usr/share/nginx/html /var/cache/nginx /var/run /var/log/nginx /etc/nginx/conf.d

EXPOSE 8080

USER nginx

CMD ["nginx", "-g", "daemon off;"]
