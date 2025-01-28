#defines drive name variable
drive="$1";
#defines hostname variable
hostname="$2";
#defines username variable
username="$3";
#determines if the user will be in the wheel group
sudoUser="$4";
#defines dns variable
dns="$5";
#defines wireguard variable
wireguard="$6";
#defines wireguard killswitch variable
wgKillswitch="$7";
#defines second drive partition name variable
part3="$8";
#defines boot mode and cpu
bios="$(echo $9 | cut -d '/' -f 1)";
cpu="$(echo $9 | cut -d '/' -f 2)";
cd archinstall;
#Creation of user account
if [ "$username" != '' ];
then
	if [ "$sudoUser" == 'y' ];
	then
		useradd -mG wheel "$username";
	else
		useradd -m wheel "$username";
	fi
fi

mkdir "/home/$username/post-install";
echo -e "dns=$dns\nwireguard=$wireguard\nwgKillswitch=$wgKillswitch\npart3=$part3" > /home/$username/post-install/var.txt;
#Disables bash history
#set +o history

#sets time zone and system clock
ln -sF "usr/share/zoneinfo/America/New_York" "/etc/localtime";
hwclock --systohc;
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen;
locale-gen;
echo LANG=en_US.UTF-8 >> /etc/locale.conf;

#sets hostname and hosts
echo "$hostname" > /etc/hostname;
echo "127.0.0.1		localhost" >> /etc/hosts;

#Enables multilib repository and resyncs repos
echo -e "[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf;
pacman -Syy

#installs desired packages
pacman -S --noconfirm "$cpu";
pacman -S --noconfirm - < packages.txt;

#Installs linpeas
i='0';
while [[ ! -e 'linpeas.sh' ]] && [[ "$i" -lt 3 ]];
do	
	wget https://github.com/carlospolop/PEASS-ng/releases/latest/download/linpeas.sh;
	i="$((i + 1))";
	if [[ "$i" -gt '1' ]] && [[ "$i" -lt 3 ]];
	then
		echo -e "\nInstallation of linpeas failed. Retrying in ten seconds...";
		sleep 10;
	elif [ "$i" -ge 3 ];
	then
		echo - "\nInstalation of linpeas failed three times. Skipping installation.";
	fi
	
done
chmod +x linpeas.sh;
mv linpeas.sh /usr/bin/linpeas;

#Global copy delete copies
cp -r etc/* /etc;

mkinitcpio -p linux;
cat install-scripts/driver-install/grub | head -6 > /etc/default/grub;
echo -e "GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=$(blkid | grep -e "$part3" | cut -d '"'  -f 2):cryptlvm root=/dev/vg1/root\"" >> /etc/default/grub;
cat install-scripts/driver-install/grub | tail -n 57 >> /etc/default/grub;
if [ "$bios" == 'u' ];
then
	grub-install --target=x86_64-efi --bootloader-id=GRUB;
else
	grub-install --target=i386-pc "$drive";
fi


#Modifies grub configuration file
#cat install-scripts/driver-install/grub | head -6 > /etc/default/grub;
#echo -e "GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=$(blkid | grep -e "$part3" | cut -d '"'  -f 2):cryptlvm root=/dev/vg1/root\"" >> /etc/default/grub;
#cat install-scripts/driver-install/grub | tail -n 57 >> /etc/default/grub;

#Installs grub configuration file
grub-mkconfig -o /boot/grub/grub.cfg;
#mkinitcpio -p linux;

#systemd-resolved
#echo -e "nameserver $dns" > /home/$username/resolv.conf.override;

usermod -a -G libvirt "$username"

#xorg:
cat /etc/X11/xinit/xinitrc | head -n -5  >> /home/"$username"/.xinitrc; 
echo "exec i3" >> /home/"$username"/.xinitrc;

#Starts and enables systemd services and other non-systemd daemons
systemctl enable dhcpcd
systemctl enable systemd-resolved
systemctl enable systemd-networkd
systemctl enable libvirtd;
systemctl enable fail2ban;


#Disables core dumps
sysctl -p /etc/sysctl.d/9999-disable-core-dump.conf;
sysctl -w kernel.core_pattern='|/bin/false';
sysctl -w fs.suid_dumpable=0;
ulimit -c 0;
echo 'ulimit -S -c 0' >> ~/.bash_profile;


#Disables cronjobs for all users
echo "ALL" >> /etc/cron.deny;

#Disables usb storage
echo 'install usb-storage /bin/true' > /etc/modprobe.d/fake_usb.conf

#Enables memory address and heap randomization
echo "kernel.randomize_va_space = 2" >> /etc/syssctl.conf;

#Removes cofigs directory
cp install-scripts/docker-install.sh install-scripts/firewall.sh install-scripts/yay.sh install-scripts/cleanup.sh install-scripts/post-install.sh "/home/$username/post-install";
cp -r install-scripts/driver-install "/home/$username/post-install";
cd /;
rm -r archinstall;
rm archinstall-chroot.sh;


#Modifying of sudoers file
echo "%wheel ALL=(ALL:ALL) ALL" | (EDITOR="tee -a" visudo)

#Manual setting up of user password
echo "Enter password of new user acount:";
passwd "$username";
cat "/home/$username/.bashrc" > "/home/$username/.bashrc_og"
echo -e "cd post-install;\n./post-install.sh;\ncd;" >> "/home/$username/.bashrc"
chown -R "$username:$username" "/home/$username";

exit;

#harden docker
#hardened-kernal
