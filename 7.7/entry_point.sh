#!/bin/bash
# -*- coding: utf-8 -*-
#
#  upgrade-drauger
#  
#  Copyright 2023 Thomas Castleman <batcastle@draugeros.org>
#  
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#  
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#  MA 02110-1301, USA.
#  
#
function main ()
{
	### MAIN UPGRADE PROCEDURE ###
	perform_usr_merge
	echo -e " - SETTING UP NEW APT SOURCES\n\n\n"
	sudo sed -i 's/jammy/noble/g' /etc/apt/sources.list
	sudo sed -i.save 's/strigoi/nzambi/g' /etc/apt/sources.list
	bad_line=$(grep -E "partner$" /etc/apt/sources.list | grep -v "^#")
	sudo sed -i "s;$bad_line;# $bad_line;" /etc/apt/sources.list
	{
		sudo apt-get update
	} || {
		timer 10 "An error occured while updating package cache. Please make sure you have internet. We will try again shortly."
		sudo apt-get update
	} || {
		timer 20 "An error occured while updating package cache. Please make sure you have internet. We will try again shortly."
		sudo apt-get update
	} || {
		timer 30 "An error occured while updating package cache. Please make sure you have internet. We will try again shortly."
		sudo apt-get update
	} || {
		timer 60 "An error occured while updating package cache. Please make sure you have internet. We will try again shortly."
		sudo apt-get update
	} || {
		timer 10 "An error occured while updating package cache. 5 attempts have been made. Resetting system and giving up."
		sudo sed -i 's/noble/jammy/g' /etc/apt/sources.list
		sudo sed -i.save 's/nzambi/strigoi/g' /etc/apt/sources.list
		sudo apt-get update
		return 2
	}

	echo -e "\n\n\n - INITIATING UPGRADE\n\n\n"
	{
		sudo apt-get -o Dpkg::Options::="--force-confold" --force-yes -y dist-upgrade
	} || {
		if [[ $(dpkg -l netcat-traditional | grep "^ii" | awk '{print $2}') == "netcat-traditional" ]]; then
			sudo apt-get --force-yes -y purge netcat-traditional
		fi
		sudo apt-get -o Dpkg::Options::="--force-confold" --force-yes -y dist-upgrade
	} || {
		sudo apt-get -o Dpkg::Options::="--force-confold" --force-yes -y install --fix-broken
		autopurge
		sudo apt-get -o Dpkg::Options::="--force-confold" --force-yes -y dist-upgrade
	}

	echo -e "\n\n\nMAIN UPGRADE COMPLETE\n\n\n"
	yes_array=("yes Yes YES y Y")
	no_array=("no No NO n N")

	# KDE Changeover
	# Wayland Changeover

	# Confirm user is using Pipewire, enforce change over if not
	# Confirm user is using systemd-boot-manager if on EFI, enforce change over if not

	autopurge
	sudo apt-get clean
}

function disclosure ()
{
	changes=""
	added_time=0
	if [[ -f /usr/bin/pulseaudio ]]; then
		changes="

$(BOLD)PIPEWIRE$(RESET)
During the upgrade from Drauger OS 7.5.1, users had the option to upgrade from PulseAudio to Pipewire. Now, with the upgrade from Drauger OS 7.6, PulseAudio is no longer going to be supported. As such, all users will be required to upgrade to Pipewire if they wish to retain support for their OS.

Pipewire is a next-generation audio interface for software. It spoofs PulseAudio, so all your PulseAudio apps will continue to work as they have before. It also offers lower audio latency, better Bluetooth support, and better audio integration with apps and games running in Wine or Proton."
		added_time=$((added_time+10))
	fi
	if [[ ! -f /usr/bin/systemd-boot-manager ]]; then
		if [[ -d /boot/efi/EFI/systemd ]]; then
			changes="$changes

$(BOLD)SYSTEMD-BOOT-MANAGER$(RESET)
During the upgrade from Drauger OS 7.5.1, users had the option to upgrade from a simple script to handle their bootloader, to the new systemd-boot-manager package. This change only applies to users using UEFI/EFI installations of Drauger OS. We detected you are using one of these installations, so this change may apply to you.

Systemd-Boot-Manager allows easier control of your bootloader, is less error prone, and is capable of receiving updates, unlike the script which was originally being used."
			added_time=$((added_time+10))
		fi
	fi

	if [[ "$changes" == "" ]]; then
		# None of the mandatory changes apply to this system. Bypass the rest of this function
		return 1
	fi

	echo -e "
\t\t### DISCLOSURE OF ENFORCED CHANGES ###

During the upgrade to the new version of Drauger OS, a few changes will be enforced. If you have no idea what these are, you are safe to move on. However, it is encouraged that all users read the below disclousure to understand the changes that will occur if they agree to them. These changes are mandatory. If you agree to the upgrade, these changes $(BOLD)will$(RESET) occur.$changes

If you installed Drauger OS for the first time with version 7.6, these changes do not apply to you. However, if you upgraded your system from Drauger OS 7.5.1, you may be among the small number of users who are affected by this change."
	timer $((added_time+10)) "Please read the above disclosure(s)."
}

function perform_usr_merge ()
{
	set +Ee

	sudo apt-get update
	{
		sudo apt-get -o Dpkg::Options::="--force-confold" --force-yes -y install usrmerge
	} || {
		output=$(sudo /usr/lib/usrmerge/convert-usrmerge 2>&1 | grep -E "^Both .* and .* exist.$" | sed -E 's/Both | and| exist.//g')
		if [[ "$output" == "" ]]; then
			set -Ee
			return
		fi
		old_IFS="$IFS"
		export IFS='\n'
		while true; do
			for each in $output; do
				file_1=$(echo "$each" | awk '{print $1}')
				file_2=$(echo "$each" | awk '{print $2}')
				md5_1=$(md5sum $file_1 | awk '{print $1}')
				md5_2=$(md5sum $file_2 | awk '{print $1}')
				if [[ "$md5_1" == "$md5_2" ]]; then
					if [[ "/usr" == ${file_1::4} ]]; then
						sudo rm -fv "$file_2"
					else
						sudo rm -fv "$file_1"
					fi
				else
					mod_time_1=$(stat --format=%Y "$file_1")
					mod_time_2=$(stat --format=%Y "$file_2")
					if [[ "$mod_time_1" -gt "$mod_time_2" ]]; then
						sudo rm -fv "$file_2"
					elif [[ "$mod_time_2" -gt "$mod_time_1" ]]; then
						sudo rm -fv "$file_1"
					else
						if [[ "/usr" == ${file_1::4} ]]; then
							sudo rm -fv "$file_2"
						else
							sudo rm -fv "$file_1"
						fi
					fi
				fi
			done
			output=$(sudo /usr/lib/usrmerge/convert-usrmerge 2>&1 | grep -E "^Both .* and .* exist.$" | sed -E 's/Both | and| exist.//g')
			if [[ "$output" == "" ]]; then
				break
			fi
		done
		export IFS="$old_IFS"
	}
	set -Ee
}

function major_changes ()
{
	# Handle all major, but optional, changes here
	echo -e "
\t\t\t### DESKTOP ENVIRONMENT CHANGE OVER ###

With the release of Drauger OS 7.7 Nzambi, the default desktop environment of Drauger OS is being changed from Xfce to KDE Plasma.

Performance of a KDE Plasma system should be near identical to that if a Xfce system."
	mem=$(lsmem -b | grep "Total online memory" | awk '{print $4}')
	mem=$((mem/(1024*1024*1024)))
	wait_time=10
	if [[ "$mem" -le "2" ]]; then
		echo -e "
However, we have detected that your system has 2 GB or less of memory. We strongly suggest that you do not opt for this upgrade as KDE Plasma requires more memory than Xfce does. However, you still have the option to opt for this upgrade, if you so choose."
		wait_time=$((wait_time+15))
	fi
	echo -e "
Opting for this upgrade will also provide you with the ability to use Wayland, if you so choose.
"
	timer "$wait_time" "If you haven't already, please make sure you read the above statment."
	confirmation
	if [[ "$?" == "1" ]]; then
		return
	fi
	sudo apt-get update
	sudo apt-get -o Dpkg::Options::="--force-confold" --force-yes -y --install-recommends install plasma-desktop sddm drauger-plasma-theme plasma-workspace-wayland
	return 0
}

function mandatory_changes ()
{
	# Handle all mandatory changes here
	if [[ -f /usr/bin/pulseaudio ]]; then
		sudo apt-get -o Dpkg::Options::="--force-confold" --force-yes -y purge pulseaudio
		sudo apt-get -o Dpkg::Options::="--force-confold" --force-yes -y install pipewire pipewire-pulse wireplumber libspa-0.2-modules libspa-0.2-bluetooth
	fi
	if [[ ! -f /usr/bin/systemd-boot-manager ]]; then
		if [[ -d /boot/efi/EFI/systemd ]]; then
			sudo apt-get -o Dpkg::Options::="--force-confold" --force-yes -y install systemd-boot-manager
			root_part=$(lsblk --output path,mountpoint | grep "/$" | awk '{print $1}')
			root_uuid=$(lsblk --output path,uuid "$root_part" | grep "^$root_part" | awk '{print $2}')
			sudo systemd-boot-manager --key=uuid
			echo "$root_uuid" | sudo tee /etc/systemd-boot-manager/UUID.conf
			sudo systemd-boot-manager --default Drauger_OS.conf
			sudo systemd-boot-manager --enable
			sudo systemd-boot-manager --update

		fi
	fi
	return 0
}
