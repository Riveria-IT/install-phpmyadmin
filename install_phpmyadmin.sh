#!/bin/bash
set -e

echo "🚀 Starte phpMyAdmin-Installation..."

if [ "$EUID" -ne 0 ]; then
  echo "❌ Bitte als root oder mit sudo ausführen."
  exit 1
fi

read -p "👤 MySQL-Benutzername (z. B. root): " MYSQL_USER
read -s -p "🔑 Passwort für $MYSQL_USER: " MYSQL_PASS
echo ""

function check_installed() {
  dpkg -s "$1" &>/dev/null
}

# Apache
if check_installed apache2; then
  echo "✅ Apache ist installiert"
else
  apt update
  apt install -y apache2
fi

# PHP
if check_installed php; then
  echo "✅ PHP ist installiert"
else
  apt install -y php php-mbstring php-zip php-gd php-json php-curl php-mysql
fi

# MariaDB
if check_installed mariadb-server; then
  echo "✅ MariaDB ist installiert"
else
  apt install -y mariadb-server
  systemctl enable mariadb
  systemctl start mariadb
fi

# Expect
if check_installed expect; then
  echo "✅ expect ist installiert"
else
  apt install -y expect
fi

MYSQL_PLUGIN=$(mysql -u root -sN -e "SELECT plugin FROM mysql.user WHERE User='root';" 2>/dev/null || echo "unknown")

if [[ "$MYSQL_PLUGIN" != "mysql_native_password" ]]; then
  echo "🔐 Setze Passwort & Auth für '$MYSQL_USER'..."
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
fi

if [ -d /usr/share/phpmyadmin ]; then
  echo "✅ phpMyAdmin ist installiert"
else
  echo "⚙️ Installiere phpMyAdmin..."
  echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
  echo "phpmyadmin phpmyadmin/app-password-confirm password $MYSQL_PASS" | debconf-set-selections
  echo "phpmyadmin phpmyadmin/mysql/admin-pass password $MYSQL_PASS" | debconf-set-selections
  echo "phpmyadmin phpmyadmin/mysql/app-pass password $MYSQL_PASS" | debconf-set-selections
  echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections
  DEBIAN_FRONTEND=noninteractive apt install -y phpmyadmin
  ln -sf /etc/phpmyadmin/apache.conf /etc/apache2/conf-available/phpmyadmin.conf
  a2enconf phpmyadmin
  systemctl reload apache2
fi

IP=$(hostname -I | awk '{print $1}')
echo ""
echo "✅ phpMyAdmin erreichbar unter: http://$IP/phpmyadmin"
echo "🔑 Benutzer: $MYSQL_USER"
echo "🔑 Passwort: $MYSQL_PASS"
