# Use lightweight web server image
FROM nginx:alpine

# Copy website files to Nginx web directory
COPY . /usr/share/nginx/html

# Expose port 80
EXPOSE 80

