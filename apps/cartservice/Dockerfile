FROM nginx:1.27-alpine

# Placeholder image until cartservice source is added.
RUN mkdir -p /usr/share/nginx/html \
  && printf '%s\n' '<!doctype html><html><body><h1>cartservice scaffold</h1></body></html>' > /usr/share/nginx/html/index.html \
  && sed -i 's/listen       80;/listen       7070;/' /etc/nginx/conf.d/default.conf \
  && chown -R nginx:nginx /usr/share/nginx/html /var/cache/nginx /var/run /var/log/nginx /etc/nginx/conf.d

EXPOSE 7070

USER nginx

CMD ["nginx", "-g", "daemon off;"]
