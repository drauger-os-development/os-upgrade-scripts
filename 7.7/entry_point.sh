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
	echo -e " - SETTING UP NEW APT SOURCES\n\n\n"
	sudo sed -i 's/jammy/noble/g' /etc/apt/sources.list
	sudo sed -i.save 's/strigoi/nzambi/g' /etc/apt/sources.list
	bad_line=$(grep -E "partner$" /etc/apt/sources.list | grep -v "^E")
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
