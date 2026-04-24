FROM nginx:1.25-alpine

# 기본 Nginx 페이지를 커스텀 페이지로 교체
COPY app/index.html /usr/share/nginx/html/index.html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget -q --spider http://localhost/ || exit 1