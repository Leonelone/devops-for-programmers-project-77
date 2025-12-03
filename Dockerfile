FROM nginx:alpine

# Создаем простую HTML страницу
RUN echo "<h1>Hello from Docker Container</h1>" > /usr/share/nginx/html/index.html

# Открываем порт 80
EXPOSE 80

# Запускаем nginx
CMD ["nginx", "-g", "daemon off;"]