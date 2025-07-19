# 🚀 phpMyAdmin Auto-Installer für Debian & Ubuntu

Ein vollautomatisches Script zur Installation von **phpMyAdmin**, **Apache2**, **PHP** und **MariaDB** auf Ubuntu/Debian-Servern – ohne Konfigurationsstress.

---

## ✅ Features

- Apache2, PHP und MariaDB werden vollautomatisch installiert
- Fix für PHP 8.x + Apache (mpm_prefork)
- phpMyAdmin wird vorkonfiguriert eingerichtet
- Benutzer & Passwort werden **nicht voreingestellt** – volle Kontrolle durch dich
- Ideal für Proxmox CTs & root-Server

---

## 🧰 Voraussetzungen

- Frisches Debian 11/12 oder Ubuntu 20.04/22.04 System
- root-Zugang oder `sudo`-Rechte

---

## 📦 Installation

```bash
wget https://raw.githubusercontent.com/Riveria-IT/install-phpmyadmin-server/main/install_phpmyadmin.sh
chmod +x install_phpmyadmin.sh
sudo ./install_phpmyadmin.sh
```

Das Script installiert:
- Apache2 Webserver
- PHP + wichtige Module
- MariaDB Server
- phpMyAdmin (automatisch über externes Script)

---

## 🔐 MySQL-Benutzer erstellen (nach der Installation)

phpMyAdmin fragt nach Benutzername & Passwort. Erstelle dafür zuerst einen Datenbank-Benutzer in MariaDB:

### 1. In die MySQL/MariaDB-Konsole gehen:

```bash
sudo mariadb -u root
```

### 2. Benutzer anlegen & Rechte vergeben:

```sql
CREATE USER 'deinbenutzer'@'localhost' IDENTIFIED BY 'deinpasswort';
GRANT ALL PRIVILEGES ON *.* TO 'deinbenutzer'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EXIT;
```

🔒 Achte darauf, ein starkes Passwort zu setzen. Du kannst nun mit diesem Benutzer auf [http://<server-ip>/phpmyadmin](http://<server-ip>/phpmyadmin) einloggen.

---

## 🌐 Zugriff auf phpMyAdmin

Einfach im Browser:

```
http://<deine-server-ip>/phpmyadmin
```

Beispiel:

```text
http://192.168.2.105/phpmyadmin
```

---

## 🔁 Wiederholte Ausführung

Falls bereits Komponenten installiert sind, erkennt das Script das und überspringt diese. Du wirst gefragt, ob du bestehende Installationen entfernen möchtest (Y/N).

---

## 🛠 Fehlerbehebung

### PHP wird im Browser angezeigt (nicht ausgeführt)?

```bash
sudo a2dismod mpm_event
sudo a2enmod mpm_prefork
sudo a2enmod php8.1   # ggf. PHP-Version anpassen
sudo systemctl restart apache2
```

### MariaDB meldet: `mariadb.cnf missing`

Dann war eine alte oder beschädigte MariaDB-Installation vorhanden. In dem Fall:

```bash
sudo apt purge -y mariadb-server mariadb-common
sudo rm -rf /etc/mysql
sudo apt install -f
```

Dann Script erneut ausführen.

---

## 📂 GitHub Repository

[👉 GitHub: Riveria-IT/install-phpmyadmin-server](https://github.com/Riveria-IT/install-phpmyadmin-server)

---

## 📝 Lizenz

MIT – frei nutzbar & anpassbar. Credits willkommen 💡
