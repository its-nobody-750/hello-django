# Django Hello World

Minimal Django app with `GET /` returning `{"message": "hello world!"}`, deployed on AWS EC2 with Nginx + Gunicorn.

## Quick Start

```bash
git clone https://github.com/its-nobody-750/hello-django.git
cd hello-django
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
python manage.py runserver
curl http://localhost:8000/
```

## EC2 Deploy

1. Launch Ubuntu 22.04 t2.micro, open ports 22, 80, 443
2. `ssh -i key.pem ubuntu@<ip>`
3. `git clone https://github.com/its-nobody-750/hello-django.git && cd hello-django`
4. `cp .env.example .env` — edit with your secret key and IP
5. `bash scripts/setup_server.sh`

One script — Python, Nginx, Gunicorn systemd units, and everything is configured.

## Update

```bash
bash scripts/deploy.sh   # pull, install deps, restart
```

## Files

| File | Purpose |
|------|---------|
| `hello_app/views.py` | The `/` endpoint |
| `nginx/django_app.conf` | Nginx reverse proxy config |
| `gunicorn/gunicorn.conf.py` | Gunicorn WSGI config |
| `scripts/setup_server.sh` | Full EC2 server setup |
| `scripts/deploy.sh` | Deploy updates |
| `requirements.txt` | Django + Gunicorn |

```
Client → Nginx:80 → Gunicorn (Unix socket) → Django → {"message": "hello world!"}
```
