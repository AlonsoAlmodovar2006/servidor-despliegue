FROM nginx:alpine

RUN echo '<h1>Plataforma de Despliegue</h1><p>Servidor activo</p>' > /usr/share/nginx/html/index.html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
