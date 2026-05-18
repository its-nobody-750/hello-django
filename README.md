# Django Hello World

A minimal Django application with a single `GET /` endpoint that returns `{"message": "hello world!"}`, configured for deployment on AWS EC2 with Nginx as a reverse proxy and Gunicorn as the WSGI server.

---

## Project Structure

```
├── hello_project/          # Django project config
│   ├── settings.py
│   ├── urls.py
│   ├── wsgi.py
│   └── asgi.py
├── hello_app/              # Django app
│   ├── views.py            # <-- the "/" endpoint
│   ├── urls.py
│   └── tests.py
├── gunicorn/               # Gunicorn config
│   └── gunicorn.conf.py
├── nginx/                  # Nginx config (reference)
│   └── django_app.conf
├── scripts/                # Deployment automation
│   ├── setup_server.sh     # First-time EC2 setup
│   └── deploy.sh           # Code update & restart
├── manage.py
├── requirements.txt
├── .env.example
└── .gitignore
```

---

## Local Development

### Prerequisites

- Python 3.10+
- pip

### Setup

```bash
# Clone the repo
git clone https://github.com/its-nobody-750/django-hello-world.git
cd django-hello-world

# Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate   # Linux/macOS
# venv\Scripts\activate    # Windows

# Install dependencies
pip install -r requirements.txt

# Run the development server
python manage.py runserver

# Test the endpoint
curl http://localhost:8000/
# => {"message": "hello world!"}
```

### Run Tests

```bash
python manage.py test
```

---

## AWS EC2 Deployment

### 1. Launch an EC2 Instance

- **AMI:** Ubuntu 22.04 LTS
- **Instance type:** t2.micro (free tier eligible)
- **Security group rules:**
  | Type      | Protocol | Port | Source     |
  |-----------|----------|------|------------|
  | SSH       | TCP      | 22   | 0.0.0.0/0 |
  | HTTP      | TCP      | 80   | 0.0.0.0/0 |
  | HTTPS     | TCP      | 443  | 0.0.0.0/0 |

### 2. SSH into the instance

```bash
ssh -i /path/to/your-key.pem ubuntu@<ec2-public-ip>
```

### 3. Clone the repository

```bash
git clone https://github.com/<your-username>/django-hello-world.git
cd django-hello-world
```

### 4. Create the environment file

```bash
cp .env.example .env
```

Edit `.env` and set the values:

```
DJANGO_SECRET_KEY=<generate-a-strong-secret-key>
DJANGO_DEBUG=False
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,<ec2-public-ip>
```

Generate a secret key with:
```bash
python3 -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
```

### 5. Run the setup script

```bash
bash scripts/setup_server.sh
```

This script automates all the steps below (6-9).

### 6. Manual Step Breakdown

If you prefer to run each step individually:

#### Install system dependencies

```bash
sudo apt-get update -y
sudo apt-get install -y python3 python3-pip python3-venv nginx
```

#### Set up Python virtual environment

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python manage.py collectstatic --noinput
```

#### Configure Gunicorn socket (systemd)

Create `/etc/systemd/system/gunicorn.socket`:

```ini
[Unit]
Description=gunicorn socket

[Socket]
ListenStream=/run/gunicorn.sock
SocketUser=www-data
SocketGroup=www-data
SocketMode=0660

[Install]
WantedBy=sockets.target
```

#### Configure Gunicorn service (systemd)

Create `/etc/systemd/system/gunicorn.service`:

```ini
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
```

#### Configure Nginx

Create `/etc/nginx/sites-available/django_app`:

```nginx
upstream django {
    server unix:/run/gunicorn.sock fail_timeout=0;
}

server {
    listen 80;
    server_name _;

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
```

Enable the site:

```bash
sudo ln -sf /etc/nginx/sites-available/django_app /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
```

#### Start services

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now gunicorn.socket
sudo systemctl enable --now gunicorn.service
sudo systemctl restart nginx
```

### 7. Verify

```bash
curl http://<ec2-public-ip>/
# => {"message": "hello world!"}
```

---

## Deploying Updates

```bash
# On the EC2 instance
bash scripts/deploy.sh
```

Or manually:

```bash
cd ~/django-hello-world
git pull origin main
source venv/bin/activate
pip install -r requirements.txt
python manage.py collectstatic --noinput
sudo systemctl restart gunicorn
sudo systemctl reload nginx
```

---

## Enabling HTTPS (Optional)

```bash
sudo apt-get install -y certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

---

## Architecture

```
                         Internet
                            |
                         Nginx :80
                            |
                     (reverse proxy)
                            |
                     Gunicorn (Unix socket)
                            |
                       Django App
                    (hello_project.wsgi)
                            |
                    hello_app.views.hello_world
                            |
                    {"message": "hello world!"}
```

Nginx serves as the entry point, forwarding HTTP requests to Gunicorn via a Unix socket. Gunicorn runs the Django WSGI application, which routes `GET /` to the `hello_world` view.

---

## API

| Method | Path | Response                         |
|--------|------|----------------------------------|
| GET    | `/`  | `200 {"message": "hello world!"}` |
