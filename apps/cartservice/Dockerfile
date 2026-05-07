FROM nginx:1.27-alpine

# Placeholder image until cartservice source is added.
RUN mkdir -p /usr/share/nginx/html
RUN printf '%s\n' '<!doctype html><html><body><h1>cartservice scaffold</h1></body></html>' > /usr/share/nginx/html/index.html

EXPOSE 7070

CMD ["sh", "-c", "sed -i 's/listen       80;/listen       7070;/' /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"]
