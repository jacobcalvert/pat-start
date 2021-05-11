#!/bin/bash
##################################################################
# This is free and unencumbered software released into the public domain.
# 
# Anyone is free to copy, modify, publish, use, compile, sell, or
# distribute this software, either in source code form or as a compiled
# binary, for any purpose, commercial or non-commercial, and by any
# means.
# 
# In jurisdictions that recognize copyright laws, the author or authors
# of this software dedicate any and all copyright interest in the
# software to the public domain. We make this dedication for the benefit
# of the public at large and to the detriment of our heirs and
# successors. We intend this dedication to be an overt act of
# relinquishment in perpetuity of all present and future rights to this
# software under copyright law.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
# 
# For more information, please refer to <https://unlicense.org>
# -----------------------------------------------------------------
# File: 	pat-start.sh
# Author: 	Jacob Calvert/K4JNC <jcalvert@jacobncalvert.com>
# Date: 	07-Mar-2021
# License:  The Unlicense
# Revision History
# -----------------
# 10may21,jnc	updated launch with result of $IAM var for home dir defn and run pat as std user (non-root)
# 02apr21,jnc	added browser launch (credit https://stackoverflow.com/questions/3124556/clean-way-to-launch-the-web-browser-from-shell-script)
# 30mar21,jnc	improved teardown with ctrl-c handler and root check
# 07mar21,jnc	inital version supporting direwolf/kissattach/pat
# -----------------
# Description:
# This is a wrapper script to simplify the startup/shutdown of pat
# WL2K with direwolf as a TNC. Various config items can be set at
# the top of the script to customize for your installation.
#
#-------------- HOW TO USE THIS SCRIPT --------------
# The 'Configuration' section is filled with variables 
# meant to customize the script to your own installation.
# The 'Options' section is to turn on/off options.
#-------------- HOW THIS SCRIPT WORKS --------------
# We first capture the script config items (see 'Configuration')
#
# Then we check for root and re-execute with sudo if
# not root, passing the original user as a param $USER
#
# We install a trap for CTRL-C which cleanly shuts down the
# the various tool instantiations
#
# We start direwolf which creates the kiss endpoint (KISS_TNC_FILE)
# and logs to DIREWOLF_LOG
#
# We wait on direwolf to create KISS_TNC_FILE
#
# We set kissattach to work specifying our 'wl2k' port
# 
# We then launch the browser as the original (non-root) user, if
# the config item is set
#
# Finally launch pat as original user
#-------------- TO END THE SESSION --------------
# CTRL-C at the prompt will be trapped to our handler, which will cleanly
# teardown the services.
#
VERSION="0.3.1"

########### Configuration ###########
IAM=$(whoami)
PAT_PATH=/opt/apps/pat/pat_0.10.0_linux_amd64
USER="$(echo -e "${1}" | tr -d '[:space:]')"
PAT_DIR="/home/$USER/.wl2k/"
DIREWOLF_LOG=/tmp/direwolf.log
KISS_TNC_FILE=/tmp/kisstnc
PAT_URL="http://localhost:8080"


########### Options ###########
LAUNCH_WWW_BROWSER=1 # 1 = launch the browser, 0 = don't


########### Root Checker ###########
[ `whoami` = root ] || { sudo "$0" "$@ $IAM"; exit $?; }

########### WWW Browser Finder ###########
OPEN_URL=$(which xdg-open || which gnome-open)

########### CTRL-C trapper function ###########
function ctrl_c() {
	echo "----"
	echo "killing kissattach."
	pkill kissattach
	echo "killing direwolf."
	pkill direwolf
 	echo "killing pat"
 	pkill pat
	echo "done."
	
	exit

}

########### CTRL-C trapper ###########
trap ctrl_c INT

echo "----- Pat Start Script v$VERSION -----"
echo "Running with PAT_DIR = $PAT_DIR"

########### Start Direwolf ###########
echo "Direwolf log is in $DIREWOLF_LOG"
echo "Starting direwolf..."
nohup direwolf -t 0 -d k  -p &> $DIREWOLF_LOG &

########### wait for Direwolf to setup the kisstnc file ###########
while [ ! -e "$KISS_TNC_FILE" ]; do
	echo "waiting on $KISS_TNC_FILE to be setup"
	sleep 0.25
done

########### Start KISS attachment ###########
echo "Attaching KISS connection..."
kissattach $KISS_TNC_FILE wl2k

########### Configure KISS parms ###########
echo "Setting KISS params..."
kissparms -p wl2k -t 300 -l 100 -s 120 -r 80 -f n -c 1

########### Launch Browser ###########
if [ $LAUNCH_WWW_BROWSER -eq 1 ]; then
	# run as initial user, running browser as root is a no-no
	echo "Opening browser as $USER"
	sudo -u $USER $OPEN_URL $PAT_URL &> /dev/null
fi

########### Launch Pat ###########
echo "Starting Pat as $USER"
sudo -u $USER $PAT_PATH/pat --config $PAT_DIR/config.json --log $PAT_DIR/pat.log --mbox $PAT_DIR/mailbox --event-log $PAT_DIR/eventlog.json http 








