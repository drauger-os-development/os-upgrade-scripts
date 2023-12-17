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
set -Ee
set -o pipefail

### MAIN UPGRADE PROCEDURE ###
echo -e " - SETTING UP NEW APT SOURCES\n\n\n"
sed -i 's/jammy/noble/g' /etc/apt/sources.list
sed -i.save 's/strigoi/nzambi/g' /etc/apt/sources.list
apt-get update

echo -e "\n\n\n - INITIATING UPGRADE\n\n\n"
{
	apt-get -o Dpkg::Options::="--force-confold" --force-yes -y dist-upgrade
} || {
    apt-get -o Dpkg::Options::="--force-confold" --force-yes -y install --fix-broken
	apt-get -o Dpkg::Options::="--force-confold" --force-yes -y autopurge
	apt-get -o Dpkg::Options::="--force-confold" --force-yes -y dist-upgrade
}

echo -e "\n\n\nMAIN UPGRADE COMPLETE\n\n\n"
yes_array=("yes Yes YES y Y")
no_array=("no No NO n N")

# KDE Changeover
# Wayland Changeover

apt-get -o Dpkg::Options::="--force-confold" --force-yes -y autopurge
apt-get clean
