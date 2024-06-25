# EvilTwin PoC


## Introduction

This is a simple PoC (Proof of Concept) of a implementation of a rogue AP and what we can get from it. I didn't explore all the options available. I just got focus on intercepting HTTP and HTTPS traffic and how to do it.
The rougue AP was setup to broadcast a Open network (no encryption) to avoid issues not related to the main objetive of this test.

## Objectives

1. Interception of HTTP and HTTPS traffic by implementing a rogue AP and a mitm proxy.

2. Get used with the airbase-ng and mitmproxy utilities and its options.

## What was not an Objetive

1. Implement the techniques to automatically deploy the certificate to the victim. Because this implies phishing.

2. Implement dns spoofing (dnschef)

3. Implemet a WPA2/CCMP rougue AP

4. Generate a CA certificate with our own PKI and deploy it on the mitmproxy and victim.


## Scope of the PoC

1. All test were done with the rogue AP broadcasting a Open Network.

2. The CA certificate used was the provided by the mitmproxy utility. 

3. The victim was a Linux debian laptop.

4. The mitmproxy's CA certificate was deployed on the firefox browser iof the victim laptop.

5. Test a https site with no login

6. Test a https site with login and capture the credentials.


**Note:**
**- The victim laptop was a laptop on my lab were I manually deployed the certificated.**

## What do I need to run this PoC

1. The rogue AP is implemented by airbase-ng which is part of the aircrack-ng suite. So, you need to install it by doing:
	sudo  apt install aircrack-ng

2. That rogue AP need a DHCP server. So, you need to install it by doing:
	sudo apt install isc-dhcp-server
	
3. To see all the intercepted traffic you will need the mitmproxy. So, install it by doing:
	sudo apt install mitmproxy

4. Because this is a rogue AP it means that it has a wireless interface to allow clients to connect and another interface (it could be wireless or not) to internet.

5. The wireless interface must be compatible with the monitor mode. So, choose a right HW before going to this PoC. Not all wireless interfaces are compatible with the monitor mode.

6. Also choose a 8dbi antenna that will be good for all the testing. A normal 1 dbi will work as well but I suppose you would want to see what is around you.


## How to run this PoC

1. If all the tools we need are already installed, then run the following

	./03-EvilTwin.sh -e RougueAP

*Notes:*
1. You can add more option but this is the simple way to running it

2. Once the airbase-ng is running, launch the mitmproxy with the following line:

	mitmproxy --mode transparent --showhost


## Final notes

1. The script that implement this AP has the option to broadcast a WPA2/CCMP rogue AP but airebase-ng has no option to configure the password. So, it will ask for password and won't let you to connect to the AP network.

2. According to internet sources (I forgot the URLs), point 1 could be implemented using hostapd along with the airbase-ng. I never tried it.

3. There are many options to implement a rogue AP I just focus on the aircrack-ng suite. You can give a try to airgeddon. I didn't do it because I got a awkward HW error on my wireless adaptor.


## EvilTwin options

*Usage: ./03-EvilTwin.sh -c channel -e essid -b bssid -t AP-type*

      -c channel: AP channel to listen to (Optional, Default ch 1)
      -e essid: AP's Network ID
      -b bssid: AP's MAC (Optional, default wireless interface's MAC)
      -t AP-type: OPN|WPA2 (Optional, default OPN=Open)

## Files

*../EvilTwin-PoC/*

*03-EvilTwin.sh&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;# Script to implement the rogue AP*

*env&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;# Here, you declare interfaces*

*whitelist.cnf&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;# Client Whitelist.*

*README.md&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;# This file*

*01-mitmproxy-CAcert.png*

*02-mitmproxy-http.png*

*03-mitmproxy-browser-cyberChef-site-01.png*

*04-mitmproxy-browser-cyberChef-site-02.png*

*05-mitmproxy-cyberChef-original_cert_details-01.png*

*06-mitmproxy-cyberChef-traffic-01.png*

*07-mitmproxy-browser-login_sniffing-imperva-site-01.png*

*08-mitmproxy-browser-login_sniffing-imperva-site-02.png*

*09-mitmproxy-login_sniffing-details.png*

*09-mitmproxy-login_sniffing-original_certs_details-imperva-site-01.png*


*Notes:*
1. All png files are screenshots taken during the testings that 
proof that this PoC works 

	
## HAPPY INTERCEPTION!!!	:-)
	
	

	i
	
	
	
	
	
	

