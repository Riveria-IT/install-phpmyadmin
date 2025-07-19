# 🚀 phpMyAdmin Auto-Installer für Debian & Ubuntu

Dieses Script installiert **phpMyAdmin inkl. Apache, PHP und MariaDB** vollständig automatisiert. Es erkennt alte Installationen, entfernt sie sauber, richtet alles korrekt ein und setzt Zugangsdaten sicher – inklusive Apache-PHP Fix.

## 🧰 Unterstützt:
- Debian 10/11/12
- Ubuntu 20.04/22.04/24.04
- Funktioniert auch in Proxmox CTs

---

## 📦 Installation

```bash
wget https://raw.githubusercontent.com/Riveria-IT/install-phpmyadmin/main/install_phpmyadmin.sh
chmod +x install_phpmyadmin.sh
sudo ./install_phpmyadmin.sh
