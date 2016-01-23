#!/bin/bash
# Custom Minecraft Pocket Edition (PE) server install script for Ubuntu 15.04
# Minecraft PE is the server used for Windows 10, Android and iOS Minecraft clients
# $1 = Minecraft user name
# $2 = difficulty
# $3 = level-name
# $4 = gamemode
# $5 = white-list
# $6 = enable-command-block
# $7 = spawn-monsters
# $8 = generate-structures
# $9 = level-seed

# basic service and API settings
minecraft_server_path=/srv/minecraft_server
minecraft_user=minecraft
minecraft_group=minecraft
UUID_URL=https://api.mojang.com/users/profiles/minecraft/$1

# create user and install folder
adduser --system --no-create-home --home /srv/minecraft-server $minecraft_user
addgroup --system $minecraft_group
mkdir $minecraft_server_path
cd $minecraft_server_path

# download the PE server jar (note PE server does NOT require the Java installation that the Minecraft PC Edition does)
while ! echo y | wget -q -O - https://get.pocketmine.net/ | bash -s - -v stable; do
    sleep 10
    wget -q -O - https://get.pocketmine.net/ | bash -s - -v stable
done

# set permissions on install folder
chown -R $minecraft_user $minecraft_server_path

# adjust memory usage depending on VM size
totalMem=$(free -m | awk '/Mem:/ { print $2 }')
if [ $totalMem -lt 1024 ]; then
    memoryAlloc=512m
else
    memoryAlloc=1024m
fi

# create the uela file
touch $minecraft_server_path/eula.txt
echo 'eula=true' >> $minecraft_server_path/eula.txt

# create a service
touch /etc/systemd/system/minecraft-server.service
printf '[Unit]\nDescription=Minecraft Service\nAfter=rc-local.service\n' >> /etc/systemd/system/minecraft-server.service
printf '[Service]\nWorkingDirectory=%s\n' $minecraft_server_path >> /etc/systemd/system/minecraft-server.service
printf 'ExecStart=/usr/bin/java -Xms%s -Xmx%s -jar %s/minecraft_server.1.8.jar nogui\n' $memoryAlloc $memoryAlloc $minecraft_server_path >> /etc/systemd/system/minecraft-server.service
printf 'ExecReload=/bin/kill -HUP $MAINPID\nKillMode=process\nRestart=on-failure\n' >> /etc/systemd/system/minecraft-server.service
printf '[Install]\nWantedBy=multi-user.target\nAlias=minecraft-server.service' >> /etc/systemd/system/minecraft-server.service

# create and set permissions on user access JSON files
touch $minecraft_server_path/banned-players.json
chown $minecraft_user:$minecraft_group $minecraft_server_path/banned-players.json
touch $minecraft_server_path/banned-ips.json
chown $minecraft_user:$minecraft_group $minecraft_server_path/banned-ips.json
touch $minecraft_server_path/whitelist.json
chown $minecraft_user:$minecraft_group $minecraft_server_path/whitelist.json

# create a valid operators file using the Mojang API
touch $minecraft_server_path/ops.json
mojang_output="`wget -qO- $UUID_URL`"
rawUUID=${mojang_output:7:32}
UUID=${rawUUID:0:8}-${rawUUID:8:4}-${rawUUID:12:4}-${rawUUID:16:4}-${rawUUID:20:12}
printf '[\n {\n  \"uuid\":\"%s\",\n  \"name\":\"%s\",\n  \"level\":4\n }\n]' $UUID $1 >> $minecraft_server_path/ops.json
chown $minecraft_user:$minecraft_group $minecraft_server_path/ops.json

# set user preferences in server.properties
touch $minecraft_server_path/server.properties
chown $minecraft_user:$minecraft_group $minecraft_server_path/server.properties
# echo 'max-tick-time=-1' >> $minecraft_server_path/server.properties
printf 'difficulty=%s\n' $2 >> $minecraft_server_path/server.properties
printf 'level-name=%s\n' $3 >> $minecraft_server_path/server.properties
printf 'gamemode=%s\n' $4 >> $minecraft_server_path/server.properties
printf 'white-list=%s\n' $5 >> $minecraft_server_path/server.properties
printf 'enable-command-block=%s\n' $6 >> $minecraft_server_path/server.properties
printf 'spawn-monsters=%s\n' $7 >> $minecraft_server_path/server.properties
printf 'generate-structures=%s\n' $8 >> $minecraft_server_path/server.properties
printf 'level-seed=%s\n' $9 >> $minecraft_server_path/server.properties

systemctl start minecraft-server
