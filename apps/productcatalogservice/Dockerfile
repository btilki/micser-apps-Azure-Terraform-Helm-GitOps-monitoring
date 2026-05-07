FROM nginx:1.27-alpine

# Placeholder image until productcatalogservice source is added.
RUN mkdir -p /usr/share/nginx/html
RUN printf '%s\n' '<!doctype html><html><body><h1>productcatalogservice scaffold</h1></body></html>' > /usr/share/nginx/html/index.html

EXPOSE 3550

CMD ["sh", "-c", "sed -i 's/listen       80;/listen       3550;/' /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"]
