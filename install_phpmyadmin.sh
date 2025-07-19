#!/bin/bash
set -e

echo "🚀 Starte phpMyAdmin-Installer für Debian/Ubuntu…"

# 👤 Zugangsdaten abfragen
read -p "MySQL-Benutzername (z. B. root): " MYSQL_USER
read -s -p "Passwort für $MYSQL_USER: " MYSQL_PASS
echo

export DEBIAN_FRONTEND=noninteractive

# 🧪 Prüfen auf kaputte MariaDB-Installation
echo "🔍 Prüfe auf beschädigte oder hängende MariaDB-Installationen…"
if dpkg -l | grep -E 'mariadb|mysql-common' | grep -q '^i[^i]'; then
  echo "⚠️ Alte oder fehlerhafte MariaDB-Installation erkannt!"
  read -p "❗ Jetzt automatisch alles bereinigen? (j/n): " CLEANUP_CONFIRM
  if [[ "$CLEANUP_CONFIRM" =~ ^[JjYy]$ ]]; then
    echo "🧹 Bereinige alte MariaDB/Apache/phpMyAdmin Installationen…"
    systemctl stop apache2 mariadb 2>/dev/null || true
    dpkg --purge --force-all mariadb-common mariadb-server mariadb-client mariadb-server-core-* mariadb-client-core-* mysql-common libmariadb* 2>/dev/null || true
    apt purge -y phpmyadmin apache2 libapache2-mod-php || true
    apt autoremove -y
    rm -rf /etc/mysql /var/lib/mysql /var/log/mysql /var/log/mysql.* /etc/phpmyadmin /usr/share/phpmyadmin /var/lib/phpmyadmin
    apt --fix-broken install -y
    echo "✅ Bereinigung abgeschlossen."
  else
    echo "⏩ Überspringe Bereinigung."
  fi
fi

# 📦 Pakete installieren
echo "📦 Installiere benötigte Pakete…"
apt update
apt install -y apache2 mariadb-server php libapache2-mod-php php-mysql php-{json,zip,gd,curl,mbstring} expect curl sudo

# 🛠 Apache MPM & PHP aktivieren
PHPVER=$(php -v | head -n1 | cut -d" " -f2 | cut -d"." -f1,2)
a2dismod mpm_event || true
a2enmod mpm_prefork
a2enmod php$PHPVER
systemctl restart apache2

# 🔐 MariaDB initial konfigurieren (Passwort setzen)
echo "🔐 Sichere MariaDB-Root-Benutzer…"
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

# 🧩 phpMyAdmin installieren via externem Repo
echo "🧩 Installiere phpMyAdmin automatisch..."
bash <(curl -s https://raw.githubusercontent.com/JulianGransee/PHPMyAdminInstaller/main/install.sh) -s

# 🔁 Passwort nochmals sicher setzen
mysql -u root -p"$MYSQL_PASS" <<EOF
ALTER USER '$MYSQL_USER'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_PASS';
FLUSH PRIVILEGES;
EOF

# 🌐 Info ausgeben
IP=$(hostname -I | awk '{print $1}')
echo ""
echo "✅ Installation abgeschlossen!"
echo "🌐 phpMyAdmin erreichbar unter: http://$IP/phpmyadmin"
echo "🔐 Login: $MYSQL_USER"
echo "🔐 Passwort: $MYSQL_PASS"
