clear;
seconds='0';
echo -n "Starting graphics driver installation"
while [ "$seconds" -lt '3' ];
do
	echo -n '.'
	sleep 1;
	seconds="$(($seconds + 1))";
done
id="$(blkid | grep -e "$(cat ../var.txt | head -4 | tail -1 | cut -d '=' -f 2)" | cut -d '"'  -f 2)";
#Creates mkinitcpio file
if [ "$(lspci -v | grep -o 'NVIDIA' | head -n1)" == 'NVIDIA' ];
then
	#Installs nvidia packages
	pacman -S --noconfirm nvidia-open nvidia-utils nvidia-settings cuda cudnn lib32-nvidia-utils nvidia-container-toolkit;
	pacman -S --noconfirm nouveau
	#Modifies mkinitcpio file	
	mv mkinitcpio-nvidia.conf /etc/mkinitcpio.conf;
	mkinitcpio -p linux;
	#Modifies grub
	cat grub | head -5 > /etc/default/grub;
	echo -e "GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet nvidia-drm.modeset=1\"\nGRUB_CMDLINE_LINUX=\"cryptdevice=UUID=$id:cryptlvm root=/dev/vg1/root\"" >> /etc/default/grub;
	cat grub | tail -n 57 >> /etc/default/grub;
	grub-mkconfig -o /boot/grub/grub.cfg;
elif [ "$(lspci -v | grep -o 'NVIDIA' | head -n1)" == 'AMD' ];
then
	echo -e "\nInstalling AMD drivers currently not supported.";
	sleep 1;
else
	echo -e "\nNo graphics drivers to install.";
	sleep 1;
	fi
