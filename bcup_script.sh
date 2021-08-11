#!/bin/bash

#exit code 1 is error, exit code 0 is successful

DISK='' #FILL DISK UUID HERE!
PASSPHRASE='' #FILL DISK LUKS PASSPHRASE HERE!
DIRECTORIES=("/home" "/var" "/root" "/etc")
BCUPDIR='/mnt/bcup'
PROGRESS=0 #initialize zenity progress bar

mountdisk() {
echo $PASSPHRASE | cryptsetup luksOpen "/dev/disk/by-uuid/$DISK" bcup -
mount /dev/mapper/bcup /mnt/bcup
}

umountdisk() {
umount /dev/mapper/bcup
cryptsetup luksClose bcup
}

backup () {
systemd-inhibit rsync -avz --delete $2 --log-file="/var/log/bcup/rsync-$(date +"%F").log" $1 $BCUPDIR
#$1 is directory to back up, $2 is exclude switch for /home
#log rsync to a file with current date
#systemd-inhibit stops the system from going idle/hibernate
PROGRESS=$((PROGRESS + 20)) #increase progress variable for zenity progress bar
}

#Check if disk is plugged in
if ! lsblk -o UUID | grep -q $DISK
then
	echo "The disk isn't plugged in!"
	exit 1
fi

mountdisk

# Run dialog
if zenity --question --text "Do you want to run your backup?" --title "Backup" --width 400
then
	(
	echo "$PROGRESS" ; sleep 1
	echo "# Starting backup to external disk..."
	for i in "${DIRECTORIES[@]}"
	do if [ "$i" = /home ]
	then
		echo "# backing up $i ..."
		backup "$i" "--exclude-from=/root/bcup/exclude.txt"
		echo "$PROGRESS"
		
	else

		echo "# backing up $i ..."
		backup "$i"
		echo "$PROGRESS"
		
	fi
	done
	echo "# Done."; sleep 5
	echo "100"
	) |
	zenity --progress --title="Backup" --text="Backing up..." --width 400
	umountdisk
	exit 0
else
	echo "Backup was aborted!"
	umountdisk
	exit 1

fi



