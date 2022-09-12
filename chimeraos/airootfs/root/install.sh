#! /bin/bash


if [ $EUID -ne 0 ]; then
    echo "$(basename $0) must be run as root"
    exit 1
fi

#### Test conenction or ask the user for configuration ####
while ! ( curl -Ls https://github.com | grep '<html' > /dev/null ); do
    whiptail \
     "No internet connection detected.\n\nPlease use the network configuration tool to activate a network, then select \"Quit\" to exit the tool and continue the installation." \
     12 50 \
     --yesno \
     --yes-button "Configure" \
     --no-button "Exit"

    if [ $? -ne 0 ]; then
         exit 1
    fi

    nmtui-connect
done
#######################################

if ! frzr-bootstrap gamer; then
    whiptail --msgbox "System bootstrap step failed." 10 50
    exit 1
fi

#### Post install steps for system configuration
# Copy over all network configuration from the live session to the system
MOUNT_PATH=/tmp/frzr_root
SYS_CONN_DIR="/etc/NetworkManager/system-connections"
if [ -d ${SYS_CONN_DIR} ] && [ -n "$(ls -A ${SYS_CONN_DIR})" ]; then
    mkdir -p -m=700 ${MOUNT_PATH}${SYS_CONN_DIR}
    cp  ${SYS_CONN_DIR}/* \
        ${MOUNT_PATH}${SYS_CONN_DIR}/.
fi

# Let the user set what session they would like to use
SESSION=$(whiptail --menu "Default session select" 18 50 10 \
 "bigpicture" "Bigpicture mode" \
 "gamepadui" "Steam Deck mode" \
 "desktop" "Gnome desktop" \
  3>&1 1>&2 2>&3)
  
LIGHTDM_CONFIG_DIR="/etc/lightdm/lightdm.conf.d"
LIGHTDM_CONFIG="10-chimeraos-session.conf"
mkdir -p -m=700 ${MOUNT_PATH}${LIGHTDM_CONFIG_DIR}

if [ ${SESSION} == "bigpicture" ]; then
  echo -e "[Seat:*]\nautologin-session=steamos" > ${MOUNT_PATH}/${LIGHTDM_CONFIG_DIR}/${LIGHTDM_CONFIG}
fi
  	
if [ ${SESSION} == "gamepadui" ]; then
  echo -e "[Seat:*]\nautologin-session=gamescope-session" > ${MOUNT_PATH}/${LIGHTDM_CONFIG_DIR}/${LIGHTDM_CONFIG}
fi
	
if [ ${SESSION} == "desktop" ]; then
  echo -e "[Seat:*]\nautologin-session=gnome" > ${MOUNT_PATH}/${LIGHTDM_CONFIG_DIR}/${LIGHTDM_CONFIG}
fi

export SHOW_UI=1
frzr-deploy chimeraos/chimeraos:stable
RESULT=$?

MSG="Installation failed."
if [ "${RESULT}" == "0" ]; then
    MSG="Installation successfully completed."
elif [ "${RESULT}" == "29" ]; then
    MSG="GitHub API rate limit error encountered. Please retry installation later."
fi

if (whiptail --yesno "${MSG}\n\nWould you like to restart the computer?" 10 50); then
    reboot
fi

exit ${RESULT}
