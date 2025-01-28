clear; sleep 1;
var='';
username='';
yes_or_no(){
	if [ "$2" == '' ];
	then
		no='n';
	else
		no="$2";
	fi

	if [ "$3" == '' ];
	then
		yes='y';
	else
		yes="$3";
	fi

	if [ "$4" == '' ];
	then
		no_full='no';
	else
		no_full="$4";
	fi

	if [ "$5" == '' ];
	then
		yes_full='yes';
	else
		yes_full="$5";
	fi
	var="$(echo $1 | tr '[:upper:]' '[:lower:]' | cut -c1)";
	while [[ "$var" != "$no" ]] && [[ "$var" != "$yes" ]];
do
	echo "$var is not a valid response. Please enter $yes_full/$yes for $yes_full, or $no_full/$no for $no_full."
	read -r var;
	var="$(echo $var | tr '[:upper:]' '[:lower:]' | cut -c1)";
done
}

exit_code_check(){
if [ "$(echo $?)" != 0 ];
then
	echo "A reboot may be required to continue with the installation.";
	exit;
fi
}

if [ "$(lscpu | grep -e Architecture | cut -d ':' -f 2 | xargs | cut -d '_' -f1)" != 'x86' ];
then
	echo -e "Installation not yet supported on non-x86 computers!";
fi

echo "Enter drive name you would like to install archlinux on.";
read -r drive;

if [ ! -e "$drive" ]; then 
echo 'No drive with that name found! Exitting...';
exit;
fi

if [ "$(echo "$drive" | cut -d '/' -f 3 | cut -b -4)" == 'nvme' ];
then
	part1="$drive"'p1';
	part2="$drive"'p2';
	part3="$drive"'p3';
else
	part1="$drive"'1';
	part2="$drive"'2';
	part3="$drive"'3';
fi

if [ "$(fdisk -l | grep -e "$drive" | cut -d ' ' -f 3 | head -n1 | cut -d'.' -f1)" -lt 50 ];
then
	echo "Drive must be at least 50 Gigabytes in size! Exittting..."
	exit;
fi


echo -e "\nWould you prefer legacy booting (l) or UEFI booting (u)?"
read -r bios;
yes_or_no "$bios" 'l' 'u' "legacy" "UEFI";
bios="$var"; var='';
#unset


echo -e "\nEnter desired hostname.";
read -r hostname;

echo -e "\nWould you like to create a user account?";
read -r createUser;
yes_or_no "$createUser";
createUser="$var"; var='';

if [ "$createUser" == 'y' ];
then
	echo -e "\nEnter name of user";
	read -r username;
	echo -e "\nWould you like $username to be a sudo user?"
	read -r sudoUser;
	yes_or_no "$sudoUser";
	sudoUser="$var"; var='';	
fi

echo -e "\nEnter the ip address of your desired DNS server. (if left blank the default advertised dns server will be used)";
read -r dns;
if [ "$dns" != '' ];
then	
	ping=$(ping -c3 "$dns");
	exit_code=$(echo $?);
	ping_results="$(echo "$ping" | cut -d ":" -f 3 | cut -b 2-)";
	if [[ "$ping_results" == 'Temporary failure in name resolution' ]] || [[ "$exit_code" != '0'  ]] && [[ "$dns" != '' ]];
	then
		echo "Dns server not found! Exitting...";
		exit;
	fi
else
	dns='';
fi

echo -e "\nWould you like for your wireguard vpn to be started on boot?"
read -r wireguard;
yes_or_no "$wireguard";
wireguard="$var"; var='';
if [ "$wireguard" == 'y' ];
then
	echo -e "\nWould you like for your wireguard vpn to be the only pathway for connecting to the internet? (killswitch)"
	read -r wgKillswitch;
	yes_or_no "$wgKillswitch";
	wgKillswitch="$var"; var='';
else
	wgKillswitch='n';
fi


echo -en "\nChecking for an internet connection";
while true;
do	
	echo -n '.';
	sleep 1.25;
done &
progressPid="$(echo $!)";
ping=$(ping -c1 gnu.org); 
ping1_results="$(echo "$ping" | cut -d ":" -f 3 | cut -b 2-)";
ping=$(ping -c1 archlinux.com);
ping2_results="$(echo "$ping" | cut -d ":" -f 3 | cut -b 2-)";
if [[ "$ping1_results" == "Temporary failure in name resolution"  ]] && [[  "$ping2_results" == "Temporary failure in name resolution"  ]];
then
	kill "$progressPid";
	echo -e "\nNo internet connection!" Exitting...; 	
	exit;
else
	kill "$progressPid";
	echo -e "\nDone!";
	sleep 1;
	clear;
fi
if [ "$bios" == 'UEFI' ];
then
	parted -s "$drive" mklabel gpt;
else
	parted -s "$drive" mklabel msdos;
fi
parted -s "$drive" mkpart P fat32 1MiB 512MiB;
parted -s "$drive" mkpart P fat32 512MiB 1024MiB;	
if [ "$bios" == 'UEFI' ];
then
	#parted -s "$drive" mkpart "boot" fat32 1MiB 512MiB;
	parted -s "$drive" set 1 esp on;
	#parted -s "$drive" mkpart "ESP" fat32 512MiB 1024MiB;
	parted -s "$drive" set 2 esp on;
#else
	#parted -s "$drive" mkpart P fat32 1MiB 512MiB;
	#parted -s "$drive" set 1 esp on;
	#parted -s "$drive" mkpart P fat32 512MiB 1024MiB;
	#parted -s "$drive" set 2 esp on;
fi

parted -s "$drive" mkpart P ext4 1024MiB '100%';
if [ -e '/dev/mapper/cryptlvm' ];
then
	cryptsetup close cryptlvm;
fi
echo "Type YES to confirm the creation of the luks volume. Then, enter the password that will be used to encrypt/decrypt the drive."
cryptsetup luksFormat "$part3";
exit_code_check
cryptsetup open "$part3" cryptlvm;
exit_code_check
homeSize="";
maxSize="$(awk "BEGIN {print $(fdisk -l | grep -e cryptlvm | cut -d ':' -f 2 | cut -d 'G' -f1 | cut -d '.' -f1 | head -n1) - 44}")";
	echo -e "\nHow large should the user's home directory be in gigabytes?\nDefault: $(echo "$(awk "BEGIN {print $(awk "BEGIN {print $(fdisk -l | grep -e cryptlvm | cut -d ':' -f 2 | cut -d 'G' -f 1) - 44}") * .75}")G")\nMax size: "$(echo $maxSize"G");
	read -r homeSize;
	homeSize="$(echo "$homeSize" | tr [:lower:] [:upper:] | cut -d'G' -f1)";
	if [ "$homeSize" == '' ];
	then
		homeSize="$(echo "$(awk "BEGIN {print $(awk "BEGIN {print $(fdisk -l | grep -e cryptlvm | cut -d ':' -f 2 | cut -d 'G' -f1 | cut -d '.' -f1 | head -n1) - 44}") * .75}")G")";
		echo -e "Using default home size $homeSize\n"
	elif [[ $(echo "$homeSize" "$maxSize" | awk '$1 > $2') ]] || [[ "$(awk "BEGIN {print $homeSize * 1}")" == 0 ]]; 
	then 
		echo "Home directory either too large or not a valid number! Exitting...";
		exit;	
	fi	
pvcreate /dev/mapper/cryptlvm;
vgcreate vg1 /dev/mapper/cryptlvm;
lvcreate -L 1G vg1 -n root;
lvcreate -L 10G vg1 -n var;
lvcreate -L 5G vg1 -n tmp;
lvcreate -L 10G vg1 -n usr;
lvcreate -L 1G vg1 -n srv;
lvcreate -L 5G vg1 -n opt;
lvcreate -L 5G vg1 -n var-tmp;
lvcreate -L 1G vg1 -n mnt;
lvcreate -L 5G vg1 -n dev-shm;
lvcreate -L 1G vg1 -n usr-local;
lvcreate -L "$homeSize"G vg1 -n home;
mkfs.fat -F 32 "$part1";
mkfs.fat -F 32 "$part2";
mkfs.ext4 /dev/vg1/root;
mkfs.ext4 /dev/vg1/var;
mkfs.ext4 /dev/vg1/tmp;
mkfs.ext4 /dev/vg1/usr;
mkfs.ext4 /dev/vg1/srv;
mkfs.ext4 /dev/vg1/opt;
mkfs.ext4 /dev/vg1/var-tmp;
mkfs.ext4 /dev/vg1/mnt; 
mkfs.ext4 /dev/vg1/dev-shm; 
mkfs.ext4 /dev/vg1/usr-local;
mkfs.ext4 /dev/vg1/home;
mount "/dev/vg1/root" "/mnt";
mkdir "/mnt/boot" "/mnt/var" "/mnt/tmp" "/mnt/usr" "/mnt/srv" "/mnt/opt" "/mnt/mnt" "/mnt/dev" "/mnt/home";
mount "$part1" "/mnt/boot";
mkdir "/mnt/boot/efi";
mount "$part2" "/mnt/boot/efi";
mount "/dev/vg1/var" "/mnt/var";
mount "/dev/vg1/tmp" "/mnt/tmp";
mount "/dev/vg1/usr" "/mnt/usr";
mount "/dev/vg1/srv" "/mnt/srv";
mount "/dev/vg1/opt" "/mnt/opt";
mkdir "/mnt/var/tmp" 
mount "/dev/vg1/var-tmp" "/mnt/var/tmp";
mount "/dev/vg1/mnt" "/mnt/mnt";
mkdir "/mnt/dev/shm";
mount "/dev/vg1/dev-shm" "/mnt/dev/shm";
mkdir "/mnt/usr/local"; 
mount "/dev/vg1/usr-local" "/mnt/usr/local";
mount "/dev/vg1/home" "/mnt/home";
if [ "$(lscpu | grep -o Intel)" == 'Intel' ];
then
	cpu='intel-ucode';
else
	cpu='amd-ucode';
fi

pacstrap /mnt base linux linux-firmware vim "$cpu" lvm2;
cp archinstall-chroot.sh /mnt;
cd ..;
cp -r $(pwd) /mnt;
cd install-scripts;
arch-chroot /mnt './archinstall-chroot.sh' "$drive" "$hostname" "$username" "$sudoUser" "$dns" "$wireguard" "$wgKillswitch" "$part3" "$bios/$cpu"; 

partitions=(vg1-root vg1-home "$part1" "$part2" vg1-var vg1-var--tmp vg1-tmp vg1-usr vg1-usr--local vg1-srv vg1-opt vg1-mnt vg1-dev--shm);
i=0;
mount_part(){
case ${partitions[$i]} in
		vg1-root)
			echo -n "/      " >> /mnt/etc/fstab;
			;;
		vg1-home)
			echo -n "/home      " >> /mnt/etc/fstab;
			;;
		"$part1")
			echo -n "/boot      " >> /mnt/etc/fstab;
			;;
		"$part2")
			echo -n "/boot/efi      " >> /mnt/etc/fstab;
			;;
		vg1-var)
 			echo -n "/var      " >> /mnt/etc/fstab; 
			;;
		vg1-var--tmp)
			echo -n "/var/tmp      " >> /mnt/etc/fstab;
			;;
		vg1-tmp)
			echo -n "/tmp      " >> /mnt/etc/fstab;
			;;
		vg1-usr)
			echo -n "/usr      " >> /mnt/etc/fstab;
			;;
		vg1-usr--local)
			echo -n "/usr/local      " >> /mnt/etc/fstab;	
			;;
		vg1-srv)
			echo -n "/srv      " >> /mnt/etc/fstab;
			;;
		vg1-opt)
			echo -n "/opt      " >> /mnt/etc/fstab;
			;;
		vg1-mnt)
			echo -n "/mnt      " >> /mnt/etc/fstab;
			;;
		vg1-dev--shm)
			 echo -n "/dev/shm      " >> /mnt/etc/fstab;
			;;	
		esac
}
while [ "$i" -lt 13 ];
do
	if [ "$i" -eq 7 ];
	then
		echo "#$(blkid | grep -e "${partitions[$i]}" | tail -1 | cut -d ":" -f 1)" >> /mnt/etc/fstab;
		echo -n "UUID=$(blkid | grep -e "${partitions[$i]}" | tail -1 | cut -d ":" -f 2 | cut -d '"' -f 2)       " >> /mnt/etc/fstab;
		mount_part;
		echo -n "$(blkid | grep -e  "${partitions[$i]}" | tail -1 | cut -d " " -f 4 | cut -d '"' -f 2)               " >> /mnt/etc/fstab;
	else
		echo "#$(blkid | grep -e "${partitions[$i]}" -m 1 | cut -d ":" -f 1)" >> /mnt/etc/fstab;
		echo -n "UUID=$(blkid | grep -e "${partitions[$i]}" -m 1 | cut -d ":" -f 2 | cut -d '"' -f 2)       " >> /mnt/etc/fstab;
		mount_part;
		echo -n "$(blkid | grep -e  "${partitions[$i]}" -m 1 | cut -d " " -f 4 | cut -d '"' -f 2)               " >> /mnt/etc/fstab;

	fi

	
	case ${partitions[$i]} in
	vg1-root)
		echo -n "defaults            0 1" >> /mnt/etc/fstab;
		;;
	vg1-var--tmp | vg1-tmp | vg1-dev--shm)
		echo -n "defaults,nodev,nosuid,noexec            1 2" >> /mnt/etc/fstab;
		;;
	*)
		echo -n "defaults            0 2" >> /mnt/etc/fstab;
		;;	
	esac
	i=$(("$i" + 1));
	echo -e "\n" >> /mnt/etc/fstab;
done
echo "Installation complete. Rebooting in 5 seconds..."
sleep 5;
umount -a;
reboot;

#pickup from last save point (save to tmp)
#prompt for yay and docker installation
