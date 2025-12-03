FROM nginx:alpine

# Создаем простую HTML страницу
RUN echo "<!DOCTYPE html>\
<html>\
<head>\
    <title>Тестовое приложение</title>\
</head>\
<body>\
    <h1>Привет из Docker контейнера</h1>\
    <p>Это тестовое приложение для курса DevOps.</p>\
</body>\
</html>" > /usr/share/nginx/html/index.html

# Открываем порт 80
EXPOSE 80

# Запускаем nginx
CMD ["nginx", "-g", "daemon off;"]