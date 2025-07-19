#!/bin/bash
set -e

echo "🚀 Starte optimiertes phpMyAdmin-Installer-Skript…"

# ❓ Abfrage zur Bereinigung
read -p "❗ Bereits installierte Dienste (Apache, MariaDB, phpMyAdmin) entfernen? (j/n): " CLEANUP_CONFIRM
if [[ "$CLEANUP_CONFIRM" =~ ^[JjYy]$ ]]; then
  echo "🧹 Entferne alte Installationen..."
  systemctl stop apache2 mariadb 2>/dev/null || true
  apt purge -y phpmyadmin apache2 mariadb-server mariadb-client libapache2-mod-php || true
  apt autoremove -y
  rm -rf /etc/phpmyadmin /usr/share/phpmyadmin /var/lib/phpmyadmin /etc/mysql /var/lib/mysql /var/log/mysql
  echo "✅ Bereinigung abgeschlossen."
else
  echo "⏩ Überspringe Bereinigung."
fi

# 👤 Nutzer & Passwort
read -p "MySQL-User (z.B. root): " MYSQL_USER
read -s -p "Passwort für $MYSQL_USER: " MYSQL_PASS
echo

export DEBIAN_FRONTEND=noninteractive

apt update
apt install -y apache2 mariadb-server php libapache2-mod-php php-mysql php-{json,zip,gd,curl,mbstring} expect

# Apache MPM + PHP-Modul fix
PHPVER=$(php -v | head -n1 | cut -d" " -f2 | cut -d"." -f1,2)
a2dismod mpm_event || true
a2enmod mpm_prefork
a2enmod php$PHPVER
systemctl restart apache2

# MariaDB sichern
expect -c "
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

# MySQL-User fix
mysql -u root <<EOF
ALTER USER '$MYSQL_USER'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_PASS';
FLUSH PRIVILEGES;
EOF

# phpMyAdmin installieren (über JulianGransee)
bash <(curl -s https://raw.githubusercontent.com/JulianGransee/PHPMyAdminInstaller/main/install.sh) -s

# Fallback: Passwort nochmal setzen
if ! grep -q "AllowNoPassword" /etc/phpmyadmin/config.inc.php; then
  echo "[WARN] Debconf-Config nicht gesetzt – setze manuell..."
  mysql -u root -p"$MYSQL_PASS" <<EOF
ALTER USER '$MYSQL_USER'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_PASS';
FLUSH PRIVILEGES;
EOF
  systemctl restart apache2
fi

# 🟢 Info
IP=$(hostname -I | awk '{print $1}')
echo "✅ phpMyAdmin läuft unter: http://$IP/phpmyadmin"
echo "🔐 Login: $MYSQL_USER / $MYSQL_PASS"
