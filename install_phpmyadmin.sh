#!/bin/bash
set -e

echo "🚀 Starte phpMyAdmin Auto-Installation..."

# Sicherstellen, dass das Script als Root läuft
if [ "$EUID" -ne 0 ]; then
  echo "❌ Bitte als root oder mit sudo ausführen."
  exit 1
fi

# Vorhandene problematische MariaDB-Installationen erkennen und bereinigen
if dpkg -l | grep -q mariadb; then
  echo "⚠️ Es scheint bereits eine MariaDB-Installation zu existieren."
  read -p "Alles bereinigen und neu installieren? (j/n): " -r
  if [[ $REPLY =~ ^[JjYy]$ ]]; then
    echo "❌ Entferne alte MariaDB-Installation..."
    systemctl stop mariadb || true
    apt purge --remove '^mariadb.*' '^mysql.*' -y || true
    apt autoremove -y
    rm -rf /etc/mysql /var/lib/mysql
  else
    echo "❌ Abgebrochen."
    exit 1
  fi
fi

# Paketliste aktualisieren
apt update

# Notwendige Pakete installieren
apt install -y apache2 mariadb-server php libapache2-mod-php php-mysql php-{json,zip,gd,curl,mbstring} expect

# Apache MPM-Modul wechseln
PHPVER=$(php -v | head -n1 | cut -d" " -f2 | cut -d"." -f1,2)
a2dismod mpm_event || true
a2enmod mpm_prefork
a2enmod php$PHPVER
systemctl restart apache2

# MariaDB absichern
expect -c "
spawn mysql_secure_installation
expect \"Enter current password\" { send \"\r\" }
expect \"Set root password?\" { send \"n\r\" }
expect \"Remove anonymous users?\" { send \"y\r\" }
expect \"Disallow root login remotely?\" { send \"y\r\" }
expect \"Remove test database?\" { send \"y\r\" }
expect \"Reload privilege tables now?\" { send \"y\r\" }
expect eof
"

# phpMyAdmin installieren
export DEBIAN_FRONTEND=noninteractive
echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
echo "phpmyadmin phpmyadmin/app-password-confirm password dummy" | debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/admin-pass password dummy" | debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/app-pass password dummy" | debconf-set-selections
echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections
apt install -y phpmyadmin

# Apache phpMyAdmin Konfiguration aktivieren
ln -sf /etc/phpmyadmin/apache.conf /etc/apache2/conf-available/phpmyadmin.conf
a2enconf phpmyadmin
systemctl reload apache2

# IP auslesen
IP=$(hostname -I | awk '{print $1}')

# Hinweis
echo
echo "✅ Installation abgeschlossen!"
echo "🌐 phpMyAdmin ist erreichbar unter: http://$IP/phpmyadmin"
echo
echo "🔐 Bitte jetzt manuell einen MySQL-Benutzer mit Passwort anlegen:"
echo
echo "  sudo mariadb -u root"
echo "  CREATE USER 'deinuser'@'localhost' IDENTIFIED BY 'deinpasswort';"
echo "  GRANT ALL PRIVILEGES ON *.* TO 'deinuser'@'localhost' WITH GRANT OPTION;"
echo "  FLUSH PRIVILEGES;"
echo "  EXIT;"

# Optional: Script entfernen
read -p "🛠️ Script nach Installation löschen? (j/n): " -r
if [[ $REPLY =~ ^[JjYy]$ ]]; then
  rm -- "$0"
fi
