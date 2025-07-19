#!/bin/bash
set -e

echo "🚀 Starte phpMyAdmin Komplett-Installation (inkl. Bereinigung)..."

# Alte heruntergeladene Varianten (install_phpmyadmin.sh.1, .2, ...)
rm -f install_phpmyadmin.sh.* 2>/dev/null || true

# Root-Check
if [ "$EUID" -ne 0 ]; then
  echo "❌ Bitte als root oder mit sudo ausführen."
  exit 1
fi

# Benutzerinteraktion
read -p "👤 MySQL-Benutzername (z. B. root): " MYSQL_USER
read -s -p "🔑 Passwort für $MYSQL_USER: " MYSQL_PASS
echo ""

# Funktionen
function check_installed() {
  dpkg -s "$1" &>/dev/null
}

function remove_if_exists() {
  if check_installed "$1"; then
    echo "🧼 Entferne $1 vollständig..."
    systemctl stop "$1" 2>/dev/null || true
    apt purge --remove -y "$1"
    apt autoremove -y
  fi
}

# 🔃 Bereinigung
echo "🧹 Entferne alte Installationen..."
remove_if_exists phpmyadmin
remove_if_exists apache2
remove_if_exists mariadb-server
remove_if_exists mariadb-client
remove_if_exists expect

echo "🧼 Entferne Restdaten..."
rm -rf /usr/share/phpmyadmin /etc/phpmyadmin /var/lib/phpmyadmin /etc/mysql /var/lib/mysql

# 📦 Installation
apt update
apt install -y apache2 php php-mbstring php-zip php-gd php-json php-curl php-mysql mariadb-server expect

systemctl enable apache2
systemctl enable mariadb
systemctl start apache2
systemctl start mariadb

# 🔐 Passwort & Auth konfigurieren
echo "🔐 Konfiguriere MariaDB..."
expect -c "
set timeout 5
spawn mysql_secure_installation
expect \"Enter current password\" { send \"\r\" }
expect \"Set root password?\" { send \"y\r\" }
expect \"New password:\" { send \"$MYSQL_PASS\r\" }
expect \"Re-enter new password:\" { send \"$MYSQL_PASS\r\" }
expect \"Remove anonymous users?\" { send \"y\r\" }
expect \"Disallow root login remotely?\" { send \"y\r\" }
expect \"Remove test database?\" { send \"y\r\" }
expect \"Reload privilege tables now?\" { send \"y\r\" }
expect eof
"

mysql -u root <<EOF
ALTER USER '$MYSQL_USER'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_PASS';
FLUSH PRIVILEGES;
EOF

# ⚙️ phpMyAdmin
echo "📦 Installiere phpMyAdmin..."
echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/admin-user string $MYSQL_USER" | debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/admin-pass password $MYSQL_PASS" | debconf-set-selections
echo "phpmyadmin phpmyadmin/app-password-confirm password $MYSQL_PASS" | debconf-set-selections
echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections

DEBIAN_FRONTEND=noninteractive apt install -y phpmyadmin
ln -sf /etc/phpmyadmin/apache.conf /etc/apache2/conf-available/phpmyadmin.conf
a2enconf phpmyadmin
systemctl reload apache2

# ✅ Ergebnis
IP=$(hostname -I | awk '{print $1}')
echo ""
echo "✅ phpMyAdmin ist fertig installiert!"
echo "🌐 Zugriff: http://$IP/phpmyadmin"
echo "🔑 Benutzer: $MYSQL_USER"
echo "🔑 Passwort: $MYSQL_PASS"

# 💣 Selbstlöschung
echo "🧽 Lösche das Installationsscript selbst..."
rm -- "$0"
