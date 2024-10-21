#!/usr/bin/env bash

#################
### VARIABLES ###
#################
CURRENTPATH=$(dirname "$0")
DNFVERSION="$(readlink $(which dnf))"
LOGFILE="/tmp/config-fedora.log"
RPMFUSIONCOMP="rpmfusion-free-appstream-data rpmfusion-nonfree-appstream-data rpmfusion-free-release-tainted rpmfusion-nonfree-release-tainted"

#################
### FONCTIONS ###
#################
check_cmd() {
	if [[ $? -eq 0 ]]; then
			#echo -e "\033[32mOK\033[0m"
			echo -e "\033[32m\xE2\x9C\x94\033[0m" # vu vert
	else
			#echo -e "\033[31mERREUR\033[0m"
			echo -e "\033[31m\xE2\x9D\x8C\033[0m" # croix rouge
	fi
}

refresh_rpm_cache() {
	dnf check-update --refresh fedora-release > /dev/null 2>&1
}

check_rpm_repo() {
	if [[ -e "/etc/yum.repos.d/$1" ]]; then
		return 0
	else
		return 1
	fi
}

check_rpm_updates() {
	yes n | dnf upgrade
}

check_rpm_pkg() {
	rpm -q "$1" > /dev/null 2>&1
}

add_rpm_pkg() {
	dnf install -y --nogpgcheck "$1" >> "$LOGFILE" 2>&1
}

del_rpm_pkg() {
	if [[ "${DNFVERSION}" == "dnf-3" ]]; then
		dnf autoremove -y "$1" >> "$LOGFILE" 2>&1
	fi

	if [[ "${DNFVERSION}" == "dnf5" ]]; then
		dnf remove -y "$1" >> "$LOGFILE" 2>&1
	fi
}

swap_rpm_pkg() {
	dnf swap -y "$1" "$2" --allowerasing > /dev/null 2>&1
}

check_copr_repo() {
	if [[ ${DNFVERSION} == "dnf-3" ]]; then
		COPR_ENABLED=$(dnf copr list --enabled | grep -c "$1")
	fi

	if [[ ${DNFVERSION} == "dnf5" ]]; then
		COPR_ENABLED=$(dnf copr list | grep -v '(disabled)' | grep -c "$1")
	fi
	
	return $COPR_ENABLED
}

add_copr_repo() {
	dnf copr enable -y "$1" > /dev/null 2>&1
}

check_flatpak_updates() {
	yes n | flatpak update
}

check_flatpak_pkg() {
	flatpak info "$1" > /dev/null 2>&1
}

add_flatpak_pkg() {
	flatpak install flathub --noninteractive -y "$1" > /dev/null 2>&1
}

del_flatpak_pkg() {
	flatpak uninstall --noninteractive -y "$1" > /dev/null 2>&1
	flatpak uninstall --unused  --noninteractive -y > /dev/null 2>&1
}

need_reboot() {
	if [[ ${DNFVERSION} == "dnf-3" ]]; then
		needs-restarting -r >> "$LOGFILE" 2>&1
		NEEDRESTART="$?"
	fi

	if [[ ${DNFVERSION} == "dnf5" ]]; then
		dnf needs-restarting -r >> "$LOGFILE" 2>&1
		NEEDRESTART="$?"
	fi

	return $NEEDRESTART
}

ask_reboot() {
	echo -n -e "\033[5;33m/\ REDÉMARRAGE NÉCESSAIRE\033[0m\033[33m : Voulez-vous redémarrer le système maintenant ? [o/N] : \033[0m"
	read rebootuser
	rebootuser=${rebootuser:-n}
	if [[ ${rebootuser,,} =~ ^[oOyY]$ ]]; then
		echo -e "\n\033[0;35m Reboot via systemd ... \033[0m"
		sleep 2
		systemctl reboot
		exit
	fi
}

ask_update() {
	echo -n -e "\n\033[36mVoulez-vous lancer les MàJ maintenant ? [o/N] : \033[0m"
	read startupdate
	startupdate=${startupdate:-n}
	echo
	if [[ ${startupdate,,} =~ ^[oOyY]$ ]]; then
		clear -x
		bash "$0"
	fi
}

####################
### DEBUT SCRIPT ###
####################
### VERIF option du script
if [[ -z "$1" ]]; then
	echo "OK" > /dev/null
elif [[ "$1" == "check" ]]; then
	echo "OK" > /dev/null
else
	echo "Usage incorrect du script :"
	echo "- $(basename $0)         : Lance la config et/ou les mises à jour"
	echo "- $(basename $0) check   : Vérifie les mises à jour disponibles et propose de les lancer"
	exit 1;
fi

### VERIF si root
if [[ $(id -u) -ne "0" ]]; then
	echo -e "\033[31mERREUR\033[0m Lancer le script avec les droits root (su - root ou sudo)"
	exit 1;
fi

### VERIF si bien Fedora Workstation
if ! check_rpm_pkg fedora-release-workstation; then
	echo -e "\033[31mERREUR\033[0m Seule Fedora Workstation (GNOME) est supportée !"
	exit 2;
fi

### VERIF MàJ si option "check"
if [[ "$1" = "check" ]]; then
	echo
	echo -e -n "\033[1mRefresh du cache DNF \033[0m"
	refresh_rpm_cache
	check_cmd

	echo -e "\033[1mMises à jour disponibles RPM : \033[0m"
	check_rpm_updates

	echo

	echo -e "\033[1mMises à jour disponibles Flatpak : \033[0m"
	check_flatpak_updates

	ask_update
	exit;
fi

### INFOS fichier log
echo -e "\033[36m"
echo "Pour suivre la progression des mises à jour : tail -f $LOGFILE"
echo -e "\033[0m"
## Date dans le log
echo '-------------------' >> "$LOGFILE"
date >> "$LOGFILE"

### CONFIG système DNF
echo -e "\033[1mConfiguration du système DNF\033[0m"

if [[ $(grep -c 'fastestmirror=' /etc/dnf/dnf.conf) -lt 1 ]]; then
	echo -e -n " \xE2\x86\xB3 Configuration miroirs rapides "
	echo "fastestmirror=true" >> /etc/dnf/dnf.conf
	check_cmd
fi

if [[ $(grep -c 'max_parallel_downloads=' /etc/dnf/dnf.conf) -lt 1 ]]; then
	echo -e -n " \xE2\x86\xB3 Configuration téléchargements parallèles "
	echo "max_parallel_downloads=10" >> /etc/dnf/dnf.conf
	check_cmd
fi

if [[ $(grep -c 'countme=' /etc/dnf/dnf.conf) -lt 1 ]]; then
	echo -e -n " \xE2\x86\xB3 Configuration statistiques "
	echo "countme=false" >> /etc/dnf/dnf.conf
	check_cmd
fi

if [[ $(grep -c 'deltarpm=' /etc/dnf/dnf.conf) -lt 1 ]]; then
        echo -e -n " \xE2\x86\xB3 Configuration deltarpm "
        echo "deltarpm=false" >> /etc/dnf/dnf.conf
        check_cmd
fi

echo -e -n " \xE2\x86\xB3 Refresh du cache "
refresh_rpm_cache
check_cmd

if ! check_rpm_pkg "dnf-utils"
then
	echo -e -n " \xE2\x86\xB3 Installation de dnf-utils "
	add_rpm_pkg "dnf-utils"
	check_cmd
fi

## MAJ des paquets RPM
echo -e -n " \xE2\x86\xB3 Mise à jour des paquets RPM "
dnf upgrade -y >> "$LOGFILE" 2>&1
check_cmd

### CONFIG système Flatpak
echo -e "\033[1mConfiguration du système Flatpak\033[0m"

## MAJ des paquets Flatpak
echo -e -n " \xE2\x86\xB3 Mise à jour des paquets Flatpak "
flatpak update --noninteractive >> "$LOGFILE"  2>&1
check_cmd

### VERIF si reboot nécessaire
if ! need_reboot; then
	ask_reboot
fi

### CONFIG des dépôts
echo -e "\033[1mConfiguration des dépôts\033[0m"

## AJOUT dépôts RPM Fusion
if ! check_rpm_pkg rpmfusion-free-release; then
	echo -e -n " \xE2\x86\xB3 Installation de RPM Fusion Free "
	add_rpm_pkg "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
	check_cmd
fi

if ! check_rpm_pkg rpmfusion-nonfree-release; then
	echo -e -n " \xE2\x86\xB3 Installation de RPM Fusion Nonfree "
	add_rpm_pkg "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
	check_cmd
fi

## AJOUT dépôt Visual Studio Code
if ! check_rpm_repo vscode.repo; then
	echo -e -n " \xE2\x86\xB3 Ajout du dépôt RPM : Visual Studio Code "
	echo "[Code]
	name=Visual Studio Code
	baseurl=https://packages.microsoft.com/yumrepos/vscode
	enabled=1
	gpgcheck=1
	gpgkey=https://packages.microsoft.com/keys/microsoft.asc" 2>/dev/null > /etc/yum.repos.d/vscode.repo
	check_cmd
	sed -e 's/\t//g' -i /etc/yum.repos.d/vscode.repo
fi

## AJOUT dépôt Flathub
if [[ $(flatpak remotes | grep -c flathub) -ne 1 ]]; then
	echo -e -n " \xE2\x86\xB3 Ajout du dépôt Flatpak : Flathub "
	flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo > /dev/null
	check_cmd
fi

### INSTALL composants RPM Fusion
echo -e "\033[1mVérification des composants RPM Fusion\033[0m"

for p in $RPMFUSIONCOMP; do
	if ! check_rpm_pkg "$p"; then
		echo -e -n " \xE2\x86\xB3 Installation du composant : $p "
		add_rpm_pkg "$p"
		check_cmd
	fi
done

### INSTALL/SUPPRESSION RPM
echo -e "\033[1mGestion des paquets RPM\033[0m"
## Selon packages.list
while read -r line; do
	if [[ "$line" == add:* ]]; then
		p=${line#add:}
		if ! check_rpm_pkg "$p"; then
			echo -e -n " \xE2\x86\xB3 Installation du paquet : $p "
			add_rpm_pkg "$p"
			check_cmd
		fi
	fi
	
	if [[ "$line" == del:* ]]; then
		p=${line#del:}
		if check_rpm_pkg "$p"; then
			echo -e -n " \xE2\x86\xB3 Suppression du paquet : $p "
			del_rpm_pkg "$p"
			check_cmd
		fi
	fi
done < "$CURRENTPATH/packages.list"

## Hors packages.list
if check_rpm_pkg "libreoffice-calc" || check_rpm_pkg "libreoffice-impress" || check_rpm_pkg "libreoffice-writer"; then
	echo -e -n " \xE2\x86\xB3 Suppression des paquets : LibreOffice "

	if [[ "${DNFVERSION}" == "dnf-3" ]]; then
		dnf autoremove -y "libreoffice-*" >> "$LOGFILE" 2>&1
	fi

	if [[ "${DNFVERSION}" == "dnf5" ]]; then
		dnf remove -y "libreoffice-*" >> "$LOGFILE" 2>&1
	fi

	check_cmd
fi

### INSTALL/SUPPRESSION Flatpak
echo -e "\033[1mGestion des paquets Flatpak\033[0m"
## Selon flatpak.list
while read -r line; do
	if [[ "$line" == add:* ]]; then
		p=${line#add:}
		if ! check_flatpak_pkg "$p"; then
			echo -e -n " \xE2\x86\xB3 Installation du Flatpak : $p "
			add_flatpak_pkg "$p"
			check_cmd
		fi
	fi
	
	if [[ "$line" == del:* ]]; then
		p=${line#del:}
		if check_flatpak_pkg "$p"; then
			echo -e -n " \xE2\x86\xB3 Suppression du Flatpak : $p "
			del_flatpak_pkg "$p"
			check_cmd
		fi
	fi
done < "$CURRENTPATH/flatpak.list"

### CONFIG système
echo -e "\033[1mConfiguration personnalisée du système\033[0m"

echo

### VERIF si reboot nécessaire
if ! need_reboot; then
	ask_reboot
fi
