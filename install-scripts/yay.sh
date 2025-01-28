#!/bin/bash

#Installs yay
#add network check for aur.archlinux.org
git clone https://aur.archlinux.org/yay.git;
exit_code="$?";
while [ "$exit_code" -gt 0 ];
do
	echo -e "\nInstallation of yay failed. Retrying in ten seconds...";
	sleep 10;
	git clone https://aur.archlinux.org/yay.git;
	exit_code="$?";	
done
cd yay;
makepkg -sicC --noconfirm;
cd;

yay -S --noconfirm librewolf-bin
