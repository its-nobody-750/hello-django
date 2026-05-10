#!/bin/bash
set -euo pipefail

# --------------------------------------------------
# AWS EC2 Ubuntu 22.04 server setup script
# Run this once on a fresh EC2 instance as ubuntu user
# Usage: bash scripts/setup_server.sh
# --------------------------------------------------

APP_DIR="/home/ubuntu/django-hello-world"
DOMAIN_OR_IP="${1:-_}"

echo "=== Updating system packages ==="
sudo apt-get update -y
sudo apt-get upgrade -y

echo "=== Installing system dependencies ==="
sudo apt-get install -y python3 python3-pip python3-venv nginx certbot python3-certbot-nginx

echo "=== Setting up Python virtual environment ==="
cd "$APP_DIR"
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

echo "=== Collecting static files ==="
python manage.py collectstatic --noinput

echo "=== Creating Gunicorn log directory ==="
sudo mkdir -p /var/log/gunicorn
sudo chown -R ubuntu:ubuntu /var/log/gunicorn

echo "=== Setting up Gunicorn systemd service ==="
sudo tee /etc/systemd/system/gunicorn.service > /dev/null <<'SERVICE'
[Unit]
Description=gunicorn daemon
Requires=gunicorn.socket
After=network.target

[Service]
Type=notify
User=ubuntu
Group=www-data
WorkingDirectory=/home/ubuntu/django-hello-world
EnvironmentFile=/home/ubuntu/django-hello-world/.env
ExecStart=/home/ubuntu/django-hello-world/venv/bin/gunicorn \
    --config /home/ubuntu/django-hello-world/gunicorn/gunicorn.conf.py \
    hello_project.wsgi:application
ExecReload=/bin/kill -s HUP $MAINPID
KillMode=mixed
TimeoutStopSec=5
PrivateTmp=true

[Install]
WantedBy=multi-user.target
SERVICE

echo "=== Setting up Gunicorn socket ==="
sudo tee /etc/systemd/system/gunicorn.socket > /dev/null <<'SOCKET'
[Unit]
Description=gunicorn socket

[Socket]
ListenStream=/run/gunicorn.sock
SocketUser=www-data
SocketGroup=www-data
SocketMode=0660

[Install]
WantedBy=sockets.target
SOCKET

echo "=== Configuring Nginx ==="
sudo tee /etc/nginx/sites-available/django_app > /dev/null <<'NGINX'
upstream django {
    server unix:/run/gunicorn.sock fail_timeout=0;
}

server {
    listen 80;
    server_name _;

    client_max_body_size 10M;

    location / {
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_pass http://django;
    }

    location /static/ {
        alias /home/ubuntu/django-hello-world/staticfiles/;
    }
}
NGINX

sudo ln -sf /etc/nginx/sites-available/django_app /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

echo "=== Testing Nginx configuration ==="
sudo nginx -t

echo "=== Starting services ==="
sudo systemctl daemon-reload
sudo systemctl enable gunicorn.socket
sudo systemctl enable gunicorn.service
sudo systemctl start gunicorn.socket
sudo systemctl start gunicorn.service
sudo systemctl restart nginx

echo "=== Checking service status ==="
sudo systemctl status gunicorn.socket --no-pager
sudo systemctl status gunicorn.service --no-pager
sudo systemctl status nginx --no-pager

echo ""
echo "=== Setup complete! ==="
echo "Your app should be accessible at http://$(curl -s http://checkip.amazonaws.com)"
echo ""
echo "To enable HTTPS, run:"
echo "  sudo certbot --nginx -d your-domain.com"
