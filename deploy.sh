#!/bin/bash
set -euo pipefail

# ────────────────────────────────────────────────
DOMAIN="snake.diordev.uz"
EMAIL="l1nton707shw@gmail.com"        # для Let's Encrypt уведомлений
WEBROOT="/var/www/$DOMAIN/html"
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
# ────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
info() { echo -e "${YELLOW}[..] $1${NC}"; }
err()  { echo -e "${RED}[ERR]${NC} $1"; exit 1; }

[[ $EUID -ne 0 ]] && err "Запусти от root: sudo bash deploy.sh"

# ── 1. Зависимости ───────────────────────────────
info "Обновляю пакеты и ставлю Nginx + Certbot..."
apt-get update -qq
apt-get install -y -qq nginx certbot python3-certbot-nginx ufw
ok "Nginx и Certbot установлены"

# ── 2. Firewall ──────────────────────────────────
info "Открываю порты 80 и 443..."
ufw allow OpenSSH   > /dev/null
ufw allow 'Nginx Full' > /dev/null
ufw --force enable  > /dev/null
ok "Firewall настроен"

# ── 3. Копируем игру ─────────────────────────────
info "Копирую файлы игры в $WEBROOT..."
mkdir -p "$WEBROOT"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$SCRIPT_DIR/index.html" ]]; then
    cp "$SCRIPT_DIR/index.html" "$WEBROOT/index.html"
    ok "index.html скопирован"
else
    err "index.html не найден рядом с deploy.sh"
fi

chown -R www-data:www-data "/var/www/$DOMAIN"
chmod -R 755 "/var/www/$DOMAIN"

# ── 4. Nginx — HTTP конфиг (нужен для certbot) ───
info "Создаю Nginx конфиг для $DOMAIN..."
cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;

    root $WEBROOT;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

ln -sf "$NGINX_CONF" "/etc/nginx/sites-enabled/$DOMAIN"

# Убираем дефолтный сайт если есть
rm -f /etc/nginx/sites-enabled/default

nginx -t && systemctl reload nginx
ok "Nginx запущен на порту 80"

# ── 5. SSL через Let's Encrypt ───────────────────
info "Получаю SSL-сертификат для $DOMAIN..."
certbot --nginx \
    --non-interactive \
    --agree-tos \
    --email "$EMAIL" \
    --redirect \
    -d "$DOMAIN"
ok "SSL сертификат получен и HTTPS настроен"

# ── 6. Финальный конфиг Nginx (с кешированием) ───
info "Обновляю Nginx конфиг с оптимизациями..."
cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name $DOMAIN;

    root $WEBROOT;
    index index.html;

    ssl_certificate     /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    include             /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam         /etc/letsencrypt/ssl-dhparams.pem;

    # Заголовки безопасности
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";
    add_header Referrer-Policy "no-referrer";

    # Кеширование статики
    location ~* \.(html|css|js|ico|png|jpg|svg)$ {
        expires 1d;
        add_header Cache-Control "public, max-age=86400";
    }

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

nginx -t && systemctl reload nginx
ok "Nginx перезагружен с HTTPS конфигом"

# ── 7. Авто-обновление сертификата ───────────────
info "Проверяю авто-обновление certbot..."
systemctl enable --now certbot.timer > /dev/null 2>&1 || \
    (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet") | crontab -
ok "Авто-обновление сертификата настроено"

# ── Готово ───────────────────────────────────────
echo ""
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}  Деплой завершён!${NC}"
echo -e "${GREEN}  Игра доступна: https://$DOMAIN${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo ""
echo "  Для обновления игры:"
echo "    cp index.html $WEBROOT/index.html"
echo ""
