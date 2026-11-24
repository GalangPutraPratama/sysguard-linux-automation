FROM nginx:1.24-alpine

# Label identitas project
LABEL project="sysguard-linux-automation"
LABEL maintainer="rania"

# Copy halaman default nginx (simulated data)
COPY default.conf /etc/nginx/conf.d/default.conf

# Expose port 80
EXPOSE 80

# Healthcheck — cek nginx tiap 30 detik
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget -qO- http://localhost/ || exit 1
