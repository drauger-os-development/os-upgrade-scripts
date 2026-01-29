#!/bin/bash
# -*- coding: utf-8 -*-
#
#  upgrade-drauger
#
#  Copyright 2025 Thomas Castleman <batcastle@draugeros.org>
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
	root sed -i 's/noble/resolute/g' /etc/apt/sources.list
	root sed -i.save 's/nzambi/urgal/g' /etc/apt/sources.list
	{
		bad_line=$(grep -E "partner$" /etc/apt/sources.list | grep -v "^#")
	} || {
		# this try/catch block is needed because set -eE is enabled. Without it, this script fails if the user
		# happens to not have the partner repos enabled.
		bad_line=""
	}
	if [ "$bad_line" != "" ]; then
		sudo sed -i "s;$bad_line;# $bad_line;" /etc/apt/sources.list
	fi
	{
		root apt-get update
	} || {
		timer 10 "An error occured while updating package cache. Please make sure you have internet. We will try again shortly."
		root apt-get update
	} || {
		timer 20 "An error occured while updating package cache. Please make sure you have internet. We will try again shortly."
		root apt-get update
	} || {
		timer 30 "An error occured while updating package cache. Please make sure you have internet. We will try again shortly."
		root apt-get update
	} || {
		timer 60 "An error occured while updating package cache. Please make sure you have internet. We will try again shortly."
		root apt-get update
	} || {
		timer 10 "An error occured while updating package cache. 5 attempts have been made. Resetting system and giving up."
		root sed -i 's/resolute/noble/g' /etc/apt/sources.list
		root sed -i.save 's/urgal/nzambi/g' /etc/apt/sources.list
		root apt-get update
		return 2
	}

	echo -e "\n\n\n - INITIATING UPGRADE\n\n\n"
	if $(cat /etc/group | grep -vq 'polkitd'); then
		root groupadd polkitd
	fi
	{
		DEBIAN_FRONTEND="noninteractive" root apt-get -o Dpkg::Options::="--force-confold" --force-yes -y dist-upgrade
	} || {
		root apt-get -o Dpkg::Options::="--force-confold" --force-yes -y install --fix-broken
		autopurge
		DEBIAN_FRONTEND="noninteractive" root apt-get -o Dpkg::Options::="--force-confold" --force-yes -y dist-upgrade
	} || {
		DEBIAN_FRONTEND="noninteractive" root dpkg --configure -a --force-confold
	}
	echo -e "\n\n\nMAIN UPGRADE COMPLETE\n\n\n"
	yes_array=("yes Yes YES y Y")
	no_array=("no No NO n N")

	autopurge
	rm -v /home/$(whoami)/.drauger-tut
}

function configure ()
{
	echo -e "\n\n\nCONFIGURING KDE PLASMA\n\n\n"
	wget https://download.draugeros.org/build/config.tar.xz
	xz -dkv config.tar.xz
	tar -xvf config.tar
	cp -Rfv --preserve=all .config/* /home/$(whoami)/.config/
	rm -rfv .config config.tar config.tar.xz
	echo -e "\n\n\nKDE PLASMA CONFIGURED\n\n\n"
}

function disclosure ()
{
	changes=""
	added_time=0
	if [[ ! -f /usr/bin/startplasma-wayland ]]; then
		changes="

$(BOLD)KDE PLASMA - Wayland$(RESET)
During the upgrade to Drauger OS 7.7, users had the option to upgrade from Xfce to KDE Plasma. Now, with the upgrade to Drauger OS 7.8, Xfce is no longer going to be supported. As such, all users will be required to upgrade to KDE Plasma if they wish to retain support for their OS."
		added_time=$((added_time+10))
	fi

	if [[ "$changes" == "" ]]; then
		# None of the mandatory changes apply to this system. Bypass the rest of this function
		return 1
	fi

	echo -e "
\t\t### DISCLOSURE OF ENFORCED CHANGES ###

During the upgrade to the new version of Drauger OS, a few changes will be enforced. If you have no idea what these are, you are safe to move on. However, it is encouraged that all users read the below disclousure to understand the changes that will occur if they agree to them. These changes are mandatory. If you agree to the upgrade, these changes $(BOLD)will$(RESET) occur.$changes

If you installed Drauger OS for the first time with version 7.7, these changes do not apply to you. However, if you upgraded your system from Drauger OS 7.6 or older, you may be among the small number of users who are affected by this change."
	timer $((added_time+10)) "Please read the above disclosure(s)."
	confirmation
	if [[ "$?" == "1" ]]; then
		return 2
	fi
}

function perform_usr_merge ()
{
	set +Ee

	root apt-get update
	{
		root apt-get -o Dpkg::Options::="--force-confold" --force-yes -y install usrmerge
	} || {
		output=$(root /usr/lib/usrmerge/convert-usrmerge 2>&1 | grep -E "^Both .* and .* exist.$" | sed -E 's/Both | and| exist.//g')
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
						root rm -fv "$file_2"
					else
						root rm -fv "$file_1"
					fi
				else
					mod_time_1=$(stat --format=%Y "$file_1")
					mod_time_2=$(stat --format=%Y "$file_2")
					if [[ "$mod_time_1" -gt "$mod_time_2" ]]; then
						root rm -fv "$file_2"
					elif [[ "$mod_time_2" -gt "$mod_time_1" ]]; then
						root rm -fv "$file_1"
					else
						if [[ "/usr" == ${file_1::4} ]]; then
							root rm -fv "$file_2"
						else
							root rm -fv "$file_1"
						fi
					fi
				fi
			done
			output=$(root /usr/lib/usrmerge/convert-usrmerge 2>&1 | grep -E "^Both .* and .* exist.$" | sed -E 's/Both | and| exist.//g')
			if [[ "$output" == "" ]]; then
				break
			fi
		done
		export IFS="$old_IFS"
	}
	root apt-get -o Dpkg::Options::="--force-confold" --force-yes -y purge usrmerge
	set -Ee
}

function major_changes ()
{
	# Handle all major, but optional, changes here
	# Nothing for Drauger OS 7.8
	return 0
}

function mandatory_changes ()
{
	# Handle all mandatory changes here

	# Will will not be REMOVING Xfce. As some systems may require it due to low memory available.
	# The below if statement will check for this, and notify the user if they meet the criteria to keep Xfce.
	# If so, we won't bother installing KDE Plasma
	mem=$(lsmem -b | grep "Total online memory" | awk '{print $4}')
	mem=$((mem/(1024*1024*1024)))
	wait_time=10
	if [[ ! -f /usr/bin/startplasma-wayland ]]; then
		if [[ "$mem" -gt "2" ]]; then
			DEBIAN_FRONTEND="noninteractive" root apt-get -o Dpkg::Options::="--force-confold" --force-yes -y --install-recommends install plasma-desktop sddm drauger-plasma-theme drauger-settings-plasma plasma-workspace-wayland libnvidia-egl-wayland1 sddm-theme-breeze
			if [ -f /etc/lightdm/lightdm.conf ]; then
				auto_login=$(grep "^autologin-user" /etc/lightdm/lightdm.conf | sed 's/=/ /g' | awk '{print $2}')
			fi
			configure
			root mkdir -p /etc/sddm.conf.d
			root touch /etc/sddm.conf.d/settings.conf
			if [ "$auto_login" == "" ]; then
				echo "[General]
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell
DisplayServer=wayland

[Theme]
Current=breeze
CursorTheme=breeze-dark

[Wayland]
EnableHiDPI=true

[X11]
EnableHiDPI=true" | root tee /etc/sddm.conf.d/settings.conf
			else
				echo "[General]
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell
DisplayServer=wayland

[Autologin]
User=$auto_login
Session=plasmawayland

[Theme]
Current=breeze
CursorTheme=breeze-dark

[Wayland]
EnableHiDPI=true

[X11]
EnableHiDPI=true" | root tee /etc/sddm.conf.d/settings.conf
			fi
			DEBIAN_FRONTEND="noninteractive" root apt-get -o Dpkg::Options::="--force-confold" --force-yes -y purge lightdm
		else
			echo -e "
We have detected that your system has 2 GB or less of memory. As such, the upgrade to KDE Plasma is being bypassed for you as it requires more memory than Xfce does."
			timer "$wait_time" ""
		fi
	fi
	return 0
}
