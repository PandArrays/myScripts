#!/bin/bash
# Script de réinitialisation et configuration de SSH
# Ce script désinstalle puis réinstalle SSH, et configure l'authentification par clé.
# Assurez-vous d'avoir un accès console/local avant de l'exécuter.

# Demande de confirmation
echo "ATTENTION : Ce script va désinstaller puis réinstaller SSH et modifier sa configuration."
echo "Si vous êtes connecté en SSH, vous risquez de perdre l'accès. Avez-vous un accès console ? (o/n)"
read -r confirmation
if [[ "$confirmation" != "o" && "$confirmation" != "O" ]]; then
  echo "Annulation du script."
  exit 1
fi

# Vérification que le script est exécuté en tant que root
if [ "$EUID" -ne 0 ]; then
  echo "Veuillez exécuter ce script en tant que root ou via sudo."
  exit 1
fi

# Sauvegarde de la configuration SSH existante
BACKUP_DIR="/etc/ssh_backup_$(date +%Y%m%d%H%M%S)"
echo "=== Sauvegarde de la configuration SSH existante ==="
if [ -d /etc/ssh ]; then
  cp -r /etc/ssh "$BACKUP_DIR"
  echo "Sauvegarde effectuée dans $BACKUP_DIR"
else
  echo "Aucune configuration SSH trouvée dans /etc/ssh"
fi

# Arrêt du service SSH
echo "=== Arrêt du service SSH ==="
systemctl stop sshd 2>/dev/null || systemctl stop ssh

# Détection du gestionnaire de paquets (apt-get ou pacman)
echo "=== Détection du gestionnaire de paquets ==="
if command -v apt-get >/dev/null 2>&1; then
  PACKAGE_MANAGER="apt-get"
elif command -v pacman >/dev/null 2>&1; then
  PACKAGE_MANAGER="pacman"
else
  echo "Gestionnaire de paquets non supporté. Ce script supporte apt-get et pacman."
  exit 1
fi
echo "Gestionnaire de paquets détecté : $PACKAGE_MANAGER"

# Désinstallation de SSH
echo "=== Désinstallation de SSH ==="
if [ "$PACKAGE_MANAGER" = "apt-get" ]; then
  apt-get remove --purge -y openssh-server openssh-client
elif [ "$PACKAGE_MANAGER" = "pacman" ]; then
  pacman -Rns --noconfirm openssh
fi

# Suppression des fichiers de configuration SSH restants
echo "=== Suppression des fichiers de configuration SSH ==="
rm -rf /etc/ssh

# Réinstallation de SSH
echo "=== Réinstallation de SSH ==="
if [ "$PACKAGE_MANAGER" = "apt-get" ]; then
  apt-get update
  apt-get install -y openssh-server
elif [ "$PACKAGE_MANAGER" = "pacman" ]; then
  pacman -S --noconfirm openssh
fi

# Activation et démarrage du service SSH
echo "=== Activation et démarrage du service SSH ==="
systemctl enable sshd 2>/dev/null || systemctl enable ssh
systemctl start sshd 2>/dev/null || systemctl start ssh

# Configuration de l'authentification par clé SSH
echo "=== Configuration de l'authentification par clé SSH ==="
# Détermination du répertoire home de l'utilisateur qui a lancé le script via sudo
USER_HOME=$(eval echo "~$SUDO_USER")
if [ -z "$USER_HOME" ]; then
  USER_HOME=$HOME
fi
# Création du dossier .ssh s'il n'existe pas déjà
mkdir -p "$USER_HOME/.ssh"

# Demande à l'utilisateur de saisir le contenu de sa clé publique
echo -n "Entrez le contenu de votre clé publique (ex: ssh-ed25519 AAAAC3NzaC1lZDI1...): "
read -r pubkey

if [ -z "$pubkey" ]; then
  echo "Aucune clé saisie. Abandon."
  exit 1
fi

# Demande du nom du fichier dans lequel sauvegarder la clé publique
echo -n "Entrez le nom du fichier pour sauvegarder votre clé (par défaut: authorized_keys): "
read -r keyfile
if [ -z "$keyfile" ]; then
  keyfile="authorized_keys"
fi
TARGET_FILE="$USER_HOME/.ssh/$keyfile"

# Sauvegarde (ou ajout) de la clé publique dans le fichier cible
echo "$pubkey" >>"$TARGET_FILE"
# Correction des permissions pour le dossier .ssh et le fichier de clé
chmod 700 "$USER_HOME/.ssh"
chmod 600 "$TARGET_FILE"
chown -R "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.ssh" 2>/dev/null

# Modification de la configuration SSH pour désactiver l'authentification par mot de passe
echo "=== Modification de la configuration SSH pour désactiver l'authentification par mot de passe ==="
SSHD_CONFIG="/etc/ssh/sshd_config"
# Fonction pour mettre à jour ou ajouter une directive dans sshd_config
update_config() {
  local directive=$1
  local value=$2
  if grep -q "^[#]*\s*${directive}" "$SSHD_CONFIG"; then
    sed -i "s/^[#]*\s*${directive}.*/${directive} ${value}/" "$SSHD_CONFIG"
  else
    echo "${directive} ${value}" >>"$SSHD_CONFIG"
  fi
}
update_config "PasswordAuthentication" "no"
update_config "ChallengeResponseAuthentication" "no"
update_config "PubkeyAuthentication" "yes"

# Redémarrage du service SSH pour appliquer les changements
echo "=== Redémarrage du service SSH pour appliquer les changements ==="
systemctl restart sshd 2>/dev/null || systemctl restart ssh

echo "=== Opération terminée ==="
echo "La configuration SSH a été réinitialisée et mise à jour pour utiliser uniquement l'authentification par clé."
echo "Vérifiez que votre clé fonctionne bien avant de fermer toute session console."
