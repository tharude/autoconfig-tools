#!/bin/sh
# SSH Keys/NTP/OpenVPN auto-installer (Ubuntu/Debian)

# Script is tested and work on Ubuntu/Debian-based systems.
# It is tuned to allow only local access and is not acting as gateway trough your client!
# It's only purpose is, to create private network between your forging nodes
# for safe and secure management. Run it on your central OpenVPN server, generate
# client keys and populate the config to your nodes.
# Default OpenVPN port was moved to 11940

# sudo apt-get install sshpass

################################################
#              COLORS DEFINITION               #
################################################

# Reset
Normal='\033[0m'       # Text Reset

# Regular Colors
Black='\033[0;30m'        # Black
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White

# Bold High Intensity
BIBlack='\033[1;90m'      # Black
BIRed='\033[1;91m'        # Red
BIGreen='\033[1;92m'      # Green
BIYellow='\033[1;93m'     # Yellow
BIBlue='\033[1;94m'       # Blue
BIPurple='\033[1;95m'     # Purple
BICyan='\033[1;96m'       # Cyan
BIWhite='\033[1;97m'      # White

################################################
#             FUNCTIONS DEFINITION             #
################################################

#Display menu
show_menu(){
    echo -e "${BIGreen}##########################################################${Normal}"
    echo -e "${BIGreen}#${BIYellow} 1)${BIGreen} Create and distribute SSH Keys                      #${Normal}"
    echo -e "${BIGreen}#${BIYellow} 2)${BIGreen} Modify remote sshd_config with recommended settings #${Normal}"
    echo -e "${BIGreen}#${BIYellow} 3)${BIGreen} Remote Install NTP and force time sync              #${Normal}"
    echo -e "${BIGreen}#${BIYellow} 4)${BIGreen} Install and configure OpenVPN                       #${Normal}"
    echo -e "${BIGreen}#${BIYellow} 5)${BIGreen} Exit                                                #${Normal}"
    echo -e "${BIGreen}##########################################################${Normal}"
    echo -e "${BIYellow}Please enter a menu option and enter or ${BIRed}enter to exit. ${Normal}"
    read opt
}

#Display message choice
function option_picked() {
    MESSAGE=${@:-"${Normal}Error: No message passed"}
    echo -e "${BIRed}${MESSAGE}${Normal}"
}

#Any key
function anykey() {
        read -s -r -p "Press any key to continue..." -n 1 dummy
}

# Function to handle choices
asksure() {
echo -n "(Y/N)? "
while read -r -n 1 -s answer; do
  if [[ $answer = [YyNn] ]]; then
     [[ $answer = [Yy] ]] && retval=0
     [[ $answer = [Nn] ]] && retval=1
    break
  fi
done

echo # final linefeed

return $retval
}

# Collect connection parameters data
function conn () {
    read -e -p "Enter the remote port where ssh is listening (default 22): " -i "22" PORT
    read -e -p "Enter remote server username : " -i "${USER}" UNAME
    read -e -p "Enter remote user sudo password :" -s PASS
    echo -e "Enter remote server IP address or space separated list of servers the key will be transferred to"
    read -p "Example: 111.111.111.111 222.222.222.222 : " -a SERVERS
}

################################################
#                    CHECKS                    #
################################################

# Check if we are running Ubuntu/Debian
if [ ! -e /etc/debian_version ]; then
echo "Ubuntu/Debian based system is required!"
exit
fi

##############################################################

clear
show_menu
while [ opt != '' ]
    do
    if [[ $opt = "" ]]; then
            exit;
    else
        case $opt in

        1) clear;
        option_picked "Create and distribute SSH Keys";

        cd ~

        # Check if we already have .ssh directory

        if [ ! -e ./.ssh ]; then
                echo -e  "${BIRed}.ssh dir does not exist, creating new one${Color_Off}"
                mkdir ~/.ssh
                chmod 700 ~/.ssh
                exit
        fi

        # Key generation

        read -e -p "Enter key lengh 2048(default) or 4096: " -i "2048" KEY
        ssh-keygen -t rsa -b $KEY

        # Collecting server data

        conn;

        # Keys transfer

        for srv in "${SERVERS[@]}"
                do
                        echo -e "${BIGreen}Copying key to server:${Color_Off} ${BIYellow}${srv}${Color_Off}"
                        ssh-copy-id '-p '${PORT} ${UNAME}'@'${srv}
                done
                        echo -e "${BIGreen}Keys are copied to server(s) (or skipped if already exist)${Color_Off}"
                        echo -e "${BIRed}It's strongly recommended to disable keyboard interactive and root login to SSH!${Color_Off}"
        anykey;
        clear;
        show_menu;
        ;;

        2) clear;
            option_picked "Modify remote sshd_config with recommended settings";

        #Modifying the sshd_conf

        echo -e "${BIRed}It's strongly recommended to disable keyboard interactive and root login to SSH!${Color_Off}"
        echo -e "${BIRed}Do you want to disable it now?${Color_Off}"
        if asksure; then

                 conn;

                #Base64 encoding of the command line to be passed to remote server

                echo -e "Encoding the command for modifying remote sshd_config"
                RCOMMAND=`echo -e -n "sed -i -r 's/^#?(PermitRootLogin|PermitEmptyPasswords|PasswordAuthentication|X11Forwarding) yes/\1 no/' /etc/ssh/sshd_config" | base64 -w0`
                echo -e "Base64 encoded output from command:"
                echo $RCOMMAND
                        for srv in "${SERVERS[@]}"
                                do
                                        echo -e "${BIGreen}Enter User's sudo password at prompt${Color_Off}"
                                        ssh -t $UNAME@${srv} "echo $RCOMMAND | base64 -d | sudo bash"
                                        echo -e "${BIGreen}sshd_config on server ${BIYellow}${srv} ${BIGreen}has been modified!${Color_Off}"
                                        echo ""
                                        echo -e "${BIRed}To take effect, remote SSH server should be restarted."
                                        echo -e "This may interrupt your previously opened sessions (if you have any)!"
                                        echo -e "Do you want to restart SSH server now?${Color_Off}"
                                                if asksure; then
                                                        ssh $UNAME@${srv} sudo -S <<< $PASS service ssh restart
                                                else
                                                        echo "OK, restart it when you're ready then."
                                                fi
                                done
        else
                echo "Operation Cancelled"
        fi
        anykey;
        clear;
        show_menu;
        ;;

        3) clear;
            option_picked "Remote Install NTP and force time sync";

        ## NTP Server Install/Force Sync
        conn;
        for srv in "${SERVERS[@]}"
                do
                ssh $UNAME@${srv} sudo -S <<< $PASS apt-get update
                ssh $UNAME@${srv} sudo -S <<< $PASS apt-get install -y ntp
                ssh $UNAME@${srv} sudo -S <<< $PASS service ntp stop
                ssh $UNAME@${srv} sudo -S <<< $PASS ntpd -gq
                ssh $UNAME@${srv} sudo -S <<< $PASS service ntp start
                done
        anykey;
        clear;
        show_menu;
        ;;

        4) clear;
            option_picked "Install and configure OpenVPN";
            sudo vpninstall.sh

        anykey;
        clear;
        show_menu;
        ;;

        5) clear;
        exit;
        ;;

        x)exit;
        ;;

        \n)exit;
        ;;

        *)clear;
        option_picked "Pick an option from the menu";
        show_menu;
        ;;
    esac
fi
done
