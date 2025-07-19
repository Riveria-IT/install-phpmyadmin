#!/bin/bash
set -e

echo "\ud83d\ude80 Starte optimiertes phpMyAdmin-Installer-Skript..."

# 👤 Nutzer & Passwort
read -p "MySQL-Benutzername (z.\u200ez\u200eb. root): " MYSQL_USER
read -s -p "Passwort f\u00fcr $MYSQL_USER: " MYSQL_PASS
echo

# 🔍 Fehlerhafte MariaDB-Erkennung & Bereinigung
if dpkg -l | grep -E '^iF' | grep -q 'mariadb-common'; then
  echo "\u26a0\ufe0f Fehlerhafte MariaDB-Installation erkannt!"
  read -p "\u2757 Jetzt automatisch bereinigen und neu installieren? (j/n): " CONFIRM
  if [[ "$CONFIRM" =~ ^[JjYy]$ ]]; then
    echo "\ud83e\uddf9 Bereinige defekte MariaDB-Installation..."
    systemctl stop mariadb apache2 2>/dev/null || true
    dpkg --purge --force-all mariadb-common mariadb-server mariadb-client \
      mariadb-server-core-* mariadb-client-core-* mysql-common libmariadb* 2>/dev/null || true
    rm -rf /etc/mysql /var/lib/mysql /var/log/mysql /usr/share/mysql* /etc/alternatives/my.cnf*
    apt --fix-broken install -y
    apt update
    echo "\u2705 Bereinigt!"
  else
    echo "\u23ed\ufe0f \u00dcberspringe Bereinigung – Fehler bleibt bestehen!"
  fi
fi

export DEBIAN_FRONTEND=noninteractive
apt update
apt install -y apache2 mariadb-server php libapache2-mod-php php-mysql \
  php-{json,zip,gd,curl,mbstring} expect

# Apache MPM + PHP-Modul fixen
PHPVER=$(php -v | head -n1 | cut -d" " -f2 | cut -d"." -f1,2)
a2dismod mpm_event || true
a2enmod mpm_prefork || true
a2enmod php$PHPVER || true
systemctl restart apache2

# MariaDB sichern & root setzen
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
mysql -u root -p"$MYSQL_PASS" <<EOF
ALTER USER '$MYSQL_USER'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_PASS';
FLUSH PRIVILEGES;
EOF

# phpMyAdmin installieren (JulianGransee Repo)
bash <(curl -s https://raw.githubusercontent.com/JulianGransee/PHPMyAdminInstaller/main/install.sh) -s

IP=$(hostname -I | awk '{print $1}')
echo "\u2705 phpMyAdmin ist erreichbar unter: http://$IP/phpmyadmin"
echo "🔑 Login: $MYSQL_USER / $MYSQL_PASS"

# Cleanup Scriptdatei
rm -- "$0" 2>/dev/null || true
