#! /usr/bin/env bash

#################
### VARIABLES ###
#################
RPMFUSIONCOMP="rpmfusion-free-appstream-data rpmfusion-nonfree-appstream-data rpmfusion-free-release-tainted rpmfusion-nonfree-release-tainted"
CODEC="gstreamer1-plugins-base gstreamer1-plugins-good gstreamer1-plugins-bad-free gstreamer1-plugins-good-extras gstreamer1-plugins-bad-free-extras gstreamer1-plugins-ugly-free gstreamer1-plugin-libav gstreamer1-plugins-ugly libdvdcss gstreamer1-plugin-openh264"
GNOMECOMP="gnome-shell-extension-dash-to-dock gnome-shell-extension-appindicator"
CURRENTPATH=$(dirname "$0")
LOGFILE="/tmp/config-fedora.log"
#####################
### FIN VARIABLES ###
#####################


#################
### FONCTIONS ###
#################
check_cmd()
{
	if [[ $? -eq 0 ]]
	then
			echo -e "\033[32mOK\033[0m"
	else
			echo -e "\033[31mERREUR\033[0m"
	fi
}

refresh_rpm_cache()
{
	dnf check-update --refresh fedora-release > /dev/null 2>&1
}

check_rpm_repo()
{
	if [[ -e "/etc/yum.repos.d/$1" ]]
	then
		return 0
	else
		return 1
	fi
}

check_rpm_updates()
{
	yes n | dnf upgrade
}

check_rpm_pkg()
{
	rpm -q "$1" > /dev/null
}

add_rpm_pkg()
{
	dnf install -y --nogpgcheck "$1" >> "$LOGFILE" 2>&1
}

del_rpm_pkg()
{
	dnf autoremove -y "$1" >> "$LOGFILE" 2>&1
}

swap_rpm_pkg()
{
	dnf swap -y "$1" "$2" --allowerasing > /dev/null 2>&1
}

check_copr_repo()
{
	COPR_ENABLED=$(dnf copr list --enabled | grep -c "$1")
	return $COPR_ENABLED
}

add_copr_repo()
{
	dnf copr enable -y "$1" > /dev/null 2>&1
}

check_flatpak_updates()
{
	yes n | flatpak update
}

check_flatpak_pkg()
{
	flatpak info "$1" > /dev/null 2>&1
}

add_flatpak_pkg()
{
	flatpak install flathub --noninteractive -y "$1" > /dev/null 2>&1
}

del_flatpak_pkg()
{
	flatpak uninstall --noninteractive -y "$1" > /dev/null && flatpak uninstall --unused  --noninteractive -y > /dev/null
}

need_reboot()
{
	needs-restarting -r >> "$LOGFILE" 2>&1
}

ask_reboot()
{
	echo -n -e "\033[5;33m/\ REDÉMARRAGE NÉCESSAIRE\033[0m\033[33m : Voulez-vous redémarrer le système maintenant ? [y/N] : \033[0m"
	read rebootuser
	rebootuser=${rebootuser:-n}
	if [[ ${rebootuser,,} == "y" ]]
	then
		echo -e "\n\033[0;35m Reboot via systemd ... \033[0m"
		sleep 2
		systemctl reboot
		exit
	fi
	if [[ ${rebootuser,,} == "k" ]]
	then
		kexec_reboot
	fi
}

kexec_reboot()
{
	echo -e "\n\033[1;4;31mEXPERIMENTAL :\033[0;35m Reboot via kexec ... \033[0m"	
	LASTKERNEL=$(rpm -q kernel --qf "%{INSTALLTIME} %{VERSION}-%{RELEASE}.%{ARCH}\n" | sort -nr | awk 'NR==1 {print $2}')
	kexec -l /boot/vmlinuz-$LASTKERNEL --initrd=/boot/initramfs-$LASTKERNEL.img --reuse-cmdline
	sleep 0.5
	# kexec -e
	systemctl kexec
	exit
}

ask_update()
{
	echo -n -e "\n\033[36mVoulez-vous lancer les MàJ maintenant ? [y/N] : \033[0m"
	read startupdate
	startupdate=${startupdate:-n}
	echo ""
	if [[ ${startupdate,,} == "y" ]]
	then
		bash "$0"
	fi
}
#####################
### FIN FONCTIONS ###
#####################


####################
### DEBUT SCRIPT ###
####################
### VERIF option du script
if [[ -z "$1" ]]
then
	echo "OK" > /dev/null
elif [[ "$1" == "check" ]]
then
	echo "OK" > /dev/null
else
	echo "Usage incorrect du script :"
	echo "- $(basename $0)         : Lance la config et/ou les mises à jour"
	echo "- $(basename $0) check   : Vérifie les mises à jour disponibles et propose de les lancer"
	exit 1;
fi

### VERIF si root
if [[ $(id -u) -ne "0" ]]
then
	echo -e "\033[31mERREUR\033[0m Lancer le script avec les droits root (su - root ou sudo)"
	exit 1;
fi

### VERIF si bien Fedora Workstation
if ! check_rpm_pkg fedora-release-workstation
then
	echo -e "\033[31mERREUR\033[0m Seule Fedora Workstation (GNOME) est supportée !"
	exit 2;
fi

### INFOS fichier log
echo -e "\033[36m"
echo "Pour suivre la progression des mises à jour : tail -f $LOGFILE"
echo -e "\033[0m"

## Date dans le log
echo '-------------------' >> "$LOGFILE"
date >> "$LOGFILE"

### VERIF MàJ si option "check"
if [[ "$1" = "check" ]]
then
	echo -n "01- - Refresh du cache : "
	refresh_rpm_cache
	check_cmd

	echo "02- - Mises à jour disponibles RPM : "
	check_rpm_updates

	echo "03- - Mises à jour disponibles Flatpak : "
	check_flatpak_updates

	ask_update

	exit;
fi

### CONFIG système DNF
echo "01- Vérification de la configuration DNF"
if [[ $(grep -c 'fastestmirror=' /etc/dnf/dnf.conf) -lt 1 ]]
then
	echo -n "- - - Correction miroirs rapides : "
	echo "fastestmirror=true" >> /etc/dnf/dnf.conf
	check_cmd
fi
if [[ $(grep -c 'max_parallel_downloads=' /etc/dnf/dnf.conf) -lt 1 ]]
then
	echo -n "- - - Correction téléchargements parallèles : "
	echo "max_parallel_downloads=10" >> /etc/dnf/dnf.conf
	check_cmd
fi
if [[ $(grep -c 'countme=' /etc/dnf/dnf.conf) -lt 1 ]]
then
	echo -n "- - - Correction statistiques : "
	echo "countme=false" >> /etc/dnf/dnf.conf
	check_cmd
fi
if [[ $(grep -c 'deltarpm=' /etc/dnf/dnf.conf) -lt 1 ]]
then
        echo -n "- - - Correction deltarpm désactivés : "
        echo "deltarpm=false" >> /etc/dnf/dnf.conf
        check_cmd
fi

echo -n "- - - Refresh du cache : "
refresh_rpm_cache
check_cmd

if ! check_rpm_pkg "dnf-utils"
then
	echo -n "- - - Installation dnf-utils : "
	add_rpm_pkg "dnf-utils"
	check_cmd
fi

### MAJ des paquets RPM
echo -n "02- Mise à jour du système DNF : "
dnf upgrade -y >> "$LOGFILE" 2>&1
check_cmd

### MAJ des paquets Flatpak
echo -n "03- Mise à jour du système Flatpak : "
flatpak update --noninteractive >> "$LOGFILE"  2>&1
check_cmd

### VERIF si reboot nécessaire
if ! need_reboot
then
	ask_reboot
fi

### CONFIG des dépôts
echo "04- Vérification configuration des dépôts"

## AJOUT dépôts RPM Fusion
if ! check_rpm_pkg rpmfusion-free-release
then
	echo -n "- - - Installation RPM Fusion Free : "
	add_rpm_pkg "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
	check_cmd
fi
if ! check_rpm_pkg rpmfusion-nonfree-release
then
	echo -n "- - - Installation RPM Fusion Nonfree : "
	add_rpm_pkg "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
	check_cmd
fi

## AJOUT dépôt Visual Studio Code
if ! check_rpm_repo vscode.repo
then
	echo -n "- - - Ajout dépôt Visual Studio Code : "
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
if [[ $(flatpak remotes | grep -c flathub) -ne 1 ]]
then
	echo -n "- - - Ajout dépôt Flathub : "
	flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo > /dev/null
	check_cmd
fi

### INSTALL composants RPM Fusion
echo "05- Vérification composants RPM Fusion"
for p in $RPMFUSIONCOMP
do
	if ! check_rpm_pkg "$p"
	then
		echo -n "- - - Installation composant $p : "
		add_rpm_pkg "$p"
		check_cmd
	fi
done

### BASCULE des composants
echo "06- Vérification swapping des composants"

## FFmpeg
if check_rpm_pkg "ffmpeg-free"
then
	echo -n "- - - Swapping ffmpeg : "
	swap_rpm_pkg "ffmpeg-free" "ffmpeg" 
	check_cmd
fi

### INSTALL des codecs
echo "07- Vérification Codecs"
for p in $CODEC
do
	if ! check_rpm_pkg "$p"
	then
		echo -n "- - - Installation codec $p : "
		add_rpm_pkg "$p"
		check_cmd
	fi
done

### INSTALL composants GNOME
echo "08- Vérification composants GNOME"
for p in $GNOMECOMP
do
	if ! check_rpm_pkg "$p"
	then
		echo -n "- - - Installation composant $p : "
		add_rpm_pkg "$p"
		check_cmd
	fi
done

### INSTALL/SUPPRESSION RPM
echo "09- Gestion des paquets RPM"
## Selon packages.list
while read -r line
do
	if [[ "$line" == add:* ]]
	then
		p=${line#add:}
		if ! check_rpm_pkg "$p"
		then
			echo -n "- - - Installation paquet $p : "
			add_rpm_pkg "$p"
			check_cmd
		fi
	fi
	
	if [[ "$line" == del:* ]]
	then
		p=${line#del:}
		if check_rpm_pkg "$p"
		then
			echo -n "- - - Suppression paquet $p : "
			del_rpm_pkg "$p"
			check_cmd
		fi
	fi
done < "$CURRENTPATH/packages.list"

## Hors packages.list
if check_rpm_pkg "libreoffice-calc" || check_rpm_pkg "libreoffice-impress" || check_rpm_pkg "libreoffice-writer"
then
	echo -n "- - - Suppression paquets LibreOffice : "
	dnf autoremove -y "libreoffice-*" >> "$LOGFILE" 2>&1
	check_cmd
fi

### INSTALL/SUPPRESSION Flatpak
echo "10- Gestion des paquets Flatpak"
## Selon flatpak.list
while read -r line
do
	if [[ "$line" == add:* ]]
	then
		p=${line#add:}
		if ! check_flatpak_pkg "$p"
		then
			echo -n "- - - Installation Flatpak $p : "
			add_flatpak_pkg "$p"
			check_cmd
		fi
	fi
	
	if [[ "$line" == del:* ]]
	then
		p=${line#del:}
		if check_flatpak_pkg "$p"
		then
			echo -n "- - - Suppression Flatpak $p : "
			del_flatpak_pkg "$p"
			check_cmd
		fi
	fi
done < "$CURRENTPATH/flatpak.list"

### Vérif configuration système
echo "11- Configuration personnalisée du système"
echo -n "- - - Rien à faire pour l'instant"

### VERIF si reboot nécessaire
if ! need_reboot
then
	ask_reboot
fi
