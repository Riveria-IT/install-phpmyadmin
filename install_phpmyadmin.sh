#!/bin/bash
set -e

echo "🚀 Starte phpMyAdmin Komplett-Installation..."

# Root-Check
if [ "$EUID" -ne 0 ]; then
  echo "❌ Bitte mit sudo oder als root ausführen."
  exit 1
fi

# 🔧 Benutzer & Passwort abfragen
read -p "👤 MySQL-Benutzername (z. B. root): " MYSQL_USER
read -s -p "🔑 Passwort für $MYSQL_USER: " MYSQL_PASS
echo ""

# 📦 Vorhandene Installationen bereinigen
echo "🧹 Entferne alte Installationen..."
systemctl stop apache2 mariadb 2>/dev/null || true
apt purge --remove -y phpmyadmin apache2 mariadb-server mariadb-client libapache2-mod-php expect || true
apt autoremove -y
rm -rf /etc/phpmyadmin /usr/share/phpmyadmin /var/lib/phpmyadmin /etc/mysql /var/lib/mysql /var/log/mysql || true

# 📦 Alles neu installieren
echo "📦 Installiere Apache, PHP, MariaDB..."
apt update
apt install -y apache2 php libapache2-mod-php php-mysql php-json php-zip php-gd php-curl php-mbstring mariadb-server expect

# 🔧 Apache MPM-Fix für PHP
echo "🔧 Setze Apache MPM-Modus für PHP..."
PHP_VERSION=$(php -v | head -n1 | cut -d" " -f2 | cut -d"." -f1,2)
a2dismod mpm_event || true
a2enmod mpm_prefork
a2enmod php$PHP_VERSION
systemctl restart apache2

# 🔐 MariaDB initial absichern
echo "🔐 Sichere MariaDB..."
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

# 📁 phpMyAdmin vorbereiten
echo "⚙️ Installiere phpMyAdmin (non-interaktiv)..."
echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/admin-user string $MYSQL_USER" | debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/admin-pass password $MYSQL_PASS" | debconf-set-selections
echo "phpmyadmin phpmyadmin/app-password-confirm password $MYSQL_PASS" | debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/app-pass password $MYSQL_PASS" | debconf-set-selections
echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections

DEBIAN_FRONTEND=noninteractive apt install -y phpmyadmin

# 🔗 Verlinken & aktivieren
ln -sf /etc/phpmyadmin/apache.conf /etc/apache2/conf-available/phpmyadmin.conf
a2enconf phpmyadmin
systemctl reload apache2

# 💾 Zugang erneut manuell absichern (für den Fall, dass Debconf ignoriert wird)
echo "🔒 Setze Benutzerpasswort manuell sicherheitshalber..."
mysql -u root -p"$MYSQL_PASS" <<EOF
ALTER USER '$MYSQL_USER'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_PASS';
FLUSH PRIVILEGES;
EOF

# ✅ Erfolg
IP=$(hostname -I | awk '{print $1}')
echo ""
echo "✅ phpMyAdmin ist fertig!"
echo "🌐 Öffne im Browser: http://$IP/phpmyadmin"
echo "🔑 Benutzer: $MYSQL_USER"
echo "🔑 Passwort: $MYSQL_PASS"

# 💣 Selbstlöschung
echo "🧽 Lösche das Script..."
rm -- "$0"
