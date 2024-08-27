#!/bin/bash

[ -n "$DEBUG" ] && [[ $(echo "$DEBUG" | tr '[:upper:]' '[:lower:]') =~ ^y|yes|1|on$ ]] && \
	set -xe || set -e

[ -n "$PRETEND" ] && [[ $(echo "$PRETEND" | tr '[:upper:]' '[:lower:]') =~ ^y|yes|1|on$ ]] && \
	RUN='echo [pretend] ' || RUN=


APK_MOD=apk
CACHE_FILE=/var/cache/apk_srvpkg_index


function update() {
	SAVED_LINUX_VER=$(apk info linux-rpi4 | head -n 1)
	SAVED_SRV=$(mktemp)
	UPD_SRV=$(mktemp)
	
	for init_pkg in $(cat $CACHE_FILE); do
		echo $(apk info $init_pkg | head -n 1) >> $SAVED_SRV
	done

	$APK_MOD update
	$APK_MOD add --upgrade apk-tools
	$APK_MOD upgrade --available
	$APK_MOD cache clean

	for init_pkg in $(cat $CACHE_FILE); do
		echo $(apk info $init_pkg | head -n 1) >> $UPD_SRV
	done

	if [ x"$SAVED_LINUX_VER" != x"$(apk info linux-rpi4 | head -n 1)" ] || ! $(cmp -s /tmp/t1 /tmp/t2); then 
		echo "Kernel or service update detected, rebooting ..."
		sync
		echo -n "Rebooting in 3, "; sleep 1; echo -n "2, "; sleep 1; echo -n "1, "; sleep 1; echo "now ..."
		sleep 1
		$RUN reboot
	fi

	rm $SAVED_SRV $UPD_SRV
}


function extract_nameandversion() {
	echo "$5"
}

function index_srv_packages() {
	TEMP_FILE=$(mktemp)

	for init_script in $(find /etc/init.d -type f); do
		
		stdout=$(apk info --who-owns $init_script 2> /dev/null)
		
		if [ $? -ne 0 ]; then
			continue
		fi
		
		cpkg=$(extract_nameandversion $stdout)
		
		pkg=$(echo "$cpkg" | sed -n 's/^\([a-z0-9-]*\)\(-[0-9].*\)/\1/p')
		
		echo $pkg >> $TEMP_FILE
	done

	cat $TEMP_FILE | sort -u > $CACHE_FILE
	rm $TEMP_FILE
}

if [ ! -f $CACHE_FILE ]; then
	index_srv_packages
fi

update

exit 0
