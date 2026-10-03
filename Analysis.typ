#pagebreak(weak: true)
#align(center + horizon)[
  #text(size: 28pt, weight: "bold")[Part: Analysis and Implementation]
]
#pagebreak()

= Techniques and Wireless Tools

== Introduction

This section describes several possibilities a network can be set up and ways to infiltrate each type of network. All network types described that are not encrypted are illegal. As described in section @l-sec:laws it is not allowed to operate a network that does not take care of the security of the transferred data.

The second part of this section shows an evaluation of the most common wireless scanners. Additionally, some tools to break a WEP key are evaluated. Finally, the state of the art of wireless intrusion detection systems (WIDS) is shown.

== Open Networks with DHCP

This type of network is the easiest to infiltrate. It is often installed by a person who does not care about security and wants the maximum amount of simplicity. The access point is used out of the box and remains unconfigured. It broadcasts beacon frames which contain the needed SSID to associate to the network. After associating to the access point an IP address can be obtained by using the DHCP service.

/ Linux: The command to use the DHCP service on a network is *_dhclient ethX_* where

  - ethX is the name of the NIC which gets the new IP address

/ Windows: No additional command is used. Windows takes care of assigning IP addresses in case a DHCP server is available

== Open Networks without DHCP

In case no DHCP server is available on a network the IP information has to be gathered manually. This can either be done by trying the standard network IP addresses or by using wireless tools like Ethereal or Kismet.

/ Standard IP addresses: @ipv4 shows the three standard IP address ranges for private LANs. These ranges include:

  - 192.168.0.0/16 (private network of class C)
  - 172.16.0.0/12 (private network of class B)
  - 10.0.0.0/8 (private network of class A)

/ Tools: Several tools like Ethereal or Kismet (see also section @l-sec:wireless_scanners) simplify the search for the correct IP address range of a network. When using Ethereal some frames have to be captured and the IP address of one client gives in most cases enough information to guess a valid IP address, the IP range and the address of the gateway. Kismet goes one step further and shows this information automatically after receiving data frames.

== Open Networks with ACLs

As mentioned earlier, most access points offer the possibility to administrate ACLs which are also called _white lists_. These lists contain MAC addresses of valid stations that are allowed to connect to a network. If a station has a MAC address which is not listed in the ACL, it is blocked by the access point and its association request is denied.

Since a MAC address can be spoofed easily it is a matter of seconds to fool the access point by giving the wireless NIC a MAC address of a valid user:

/ Linux: The command to change the MAC address of a NIC is

  *_ifconfig ethX hw ether 00:AA:BB:CC:DD:EE_*

  where

  - ethX is the name of the NIC the cracker wants to spoof
  - 00:AA:BB:CC:DD:EE is the new MAC address of the NIC

  In order to reset the MAC address of the NIC to the original one the cracker has to bring it down and up again by using the commands

  *_ifconfig ethX down_* \
  *_ifconfig ethX up_*

/ Windows: There exist several tools to change the MAC address of a NIC named SMAC#footnote[A trial version of SMAC is available at: http://www.klcconsulting.net/smac/] or MacShift#footnote[MacShift is available at: http://devices.natetrue.com/macshift/]

== Cloaked Networks

Networks that are in hidden mode are hard to detect because the access point does not send out beacon frames which include the SSID. Additionally, it does not respond to probe requests in which the SSID field is not set.

One thing a cracker can do is to wait for an association of a legitimate user, capture the probe request frame sent and retrieve the SSID which is set in the request.

In case an intruder is aware of users that are currently connected to a cloaked network it is possible to speed up the process of waiting for an association of a new client: The only thing a cracker has to do is to send a disassociation request with the source address of a legitimate user which is currently connected to the network. The access point disassociates this station. Finally, the station realises that it was disconnected and reconnects automatically by sending a new association request.

== Encrypted Networks

A network that is encrypted can also be infiltrated easily in case WEP is used. Depending on the encryption technique used it is a matter of hours, days or it is practically impossible to break into a network.

The following techniques to attack a WEP or WPA protected network are also described in @wlan_sicherheit[p. 60-62] and @wlan_sicherheit[p. 130].

#heading(level: 3, numbering: none, outlined: false)[WEP Attacks]

==== Brute Force

This technique can be used for every encryption method and will always produce the correct result in case information about the plaintext is available. The idea is to try to decrypt an encrypted packet with all possible keys. The problem with this approach is that it takes a lot of time until the correct key is found. As a consequence this technique only makes sense in case a short key is used.

==== Dictionary Attack

The idea of a dictionary attack is the same as in a brute force attack. The only difference is that in a dictionary attack a predefined set of possible keys are tested instead of all possible ones. That means for example all words of an English dictionary serve as possible keys. In case the password used in a wireless network is an English word the correct key can be found faster than when using brute force since less keys have to be tested. The success of such an attack highly depends on the password chosen by the network administrator.

==== FMS

Based on the paper @rc4weak an attack was created to break the WEP key. It is named after its authors and is called FMS. The weakness focuses on the weak initialisation vectors (IVs) of RC4 which is used in WEP. There exist approximately 9000 of $2^24$ which have to be considered as insecure and can be used to perform the attack. As a consequence a lot of packets have to be captured. Additionally, manufacturers try to avoid to create weak IVs in their hardware which increases the number of packets needed. That means in detail that five to ten million (or even more) encrypted packets have to be captured before the attack succeeds. @wlan_sicherheit[p. 61f]

==== Improved FMS

In 2002 David Hulton showed that it is possible to improve the FMS algorithm. This technique requires only 500.000 to 2.000.000 packets to break a WEP key successfully. For more information on the Improved FMS attack see @improved_fms.

==== Statistical Cryptanalysis

Currently the fastest way to break a WEP key was found by a hacker named KoreK. His method does not depend on weak IVs as it is the case in the techniques described above. The basis for this attack is the number of unique IVs. The number of needed packets to break a 128-bit WEP key lies somewhere around 500.000 to 1.000.000 packets. According to @wlan_sicherheit[p. 62] KoreK did not describe the attack in papers or articles.

#heading(level: 3, numbering: none, outlined: false)[WPA Attack]

WPA is, compared to WEP, very robust @wlan_sicherheit[p. 129] and as a consequence much harder to break. Nevertheless there exist possibilities to attack. The most common one is to run an offline attack by first capturing some frames and then perform a dictionary attack. Again, the success of such an attack depends on the password chosen by the network administrator.

== Wireless Scanners <l-sec:wireless_scanners>

The following section gives a brief overview of the most common wireless scanners including Netstumbler and Kismet.

#heading(level: 3, numbering: none, outlined: false)[Netstumbler]

Netstumbler is probably the most famous wireless scanner for Windows. It was written in 2001 by Marius Milner.

#pagebreak()

The main features of Netstumbler include:

- GUI based
- Graphical presentation of the signal strength and noise values
- Filtering of different types of wireless networks
- Active scanning#footnote[See section @l-sec:active_passive_scanning for details]
- GPS support
- Support for Aironet, Hermes and Prism based NICs
- Save networks found in binary and proprietary NS1 file (Network Stumbler file)
- Export to readable text file

@l-netstumbler shows a screenshot of Netstumbler at work. The left frame groups all wireless networks found into different sections. These sections let a user group all networks found into different categories like showing only all encrypted networks, showing all infrastructure networks, etc.

#figure(
  image("graphics/Netstumbler.png", width: 100%),
  caption: [The Netstumbler GUI],
) <l-netstumbler>

#pagebreak()

On the right side detailed information about a network is shown. See also @netstumbler_columns.

/ MAC: The MAC address of the network
/ SSID: The name of the network
/ Channel: The channel the network uses
/ Speed: The maximum speed of the network in MBit/s
/ Vendor: Netstumbler identifies vendors of networking technology by comparing the first three octets of the MAC address of an access point with a predefined database that contains vendors.#footnote[A list including the mapping between MAC address and vendor name can be found at: http://standards.ieee.org/regauth/oui/oui.txt]
/ Type: Describes the type of the network. A possible value can either be _AP_ (infrastructure BSS) or _Peer_ (IBSS)
/ Encryption: Shows whether a network is WEP protected or not
/ Signal to Noise Ratio (SNR): This value indicates the offset between the signal strength and the noise. The higher the difference the better it is for the quality of the connection @snr
/ SNR+: The best SNR value of an AP found during a scan
/ Signal: The current signal strength of an AP
/ Signal+: The highest signal strength found during a scan
/ Noise: The current noise value
/ Noise-: The lowest noise value found during a scan
/ First Seen: The time an AP was discovered
/ Last Seen: The last time a frame was received by an AP
/ IP Addr and Subnet: Shows IP address range and the subnet of a wireless network
/ Latitude and Longitude: Information received by a GPS antenna
/ Beacon Interval: The interval the AP or peer uses to send out beacon frames
/ Flags: Shows the capabilities of an AP in hexadecimal notation. For detailed information about possible values see @80211standard[p. 51].

At the bottom of the window a two dimensional graph is presented which shows the SNR of a network.

#heading(level: 3, numbering: none, outlined: false)[Kismet]

Another wireless scanner for Linux is Kismet, written by Mike Kershaw. Due to the fact that it is a passive scanner (see section @l-sec:active_passive_scanning for details) the wireless NIC used to capture frames has to be able to be put into monitor mode. Since the wireless NIC can capture all frames that are sent through the air it is also possible to detect cloaked networks by scanning and dissecting data frames. Because it detects (almost) every network Kismet is very often used by wardrivers.

The main features of Kismet are (see also @kismet_readme and @guide_to_wardriving):

- GUI based on Ncurses#footnote[Ncurses is a graphic library for Linux which creates windows and panels on a console using coloured dashes. For more information on Ncurses visit its project homepage at: http://www.gnu.org/software/ncurses/ncurses.html.]
- Passive scanning
- GPS support
- Channel hopping support
- It supports "any wireless card which supports raw monitoring (rfmon) mode, and can sniff 802.11b, 802.11a, and 802.11g traffic." @kismet_readme
- Automatically logs access points to XML, CSV and GPS files
- Automatically logs raw data to pcap files
- Network IP range detection
- Detection of default access point configurations
- Manufacturer identification of access points and wireless NICs
- Show MAC addresses of clients that are connected to a network
- Present a statistic of a network

#figure(
  image("graphics/Kismet.png", width: 100%),
  caption: [The Kismet GUI],
) <l-kismet>

@l-kismet shows a screenshot of Kismet at work. The main window named _Network List_ shows detailed information about networks found:

/ Name: The SSID of the network
/ T: Type of the network. Possible values include _P_ (probe requested network), _A_ (infrastructure BSS) and _H_ (IBSS)
/ W: Encryption type used in the network. Values can be _N_ for no encryption, _Y_ for WEP encryption and _O_ for any other encryption used
/ Ch: Specifies the channel the networks uses
/ Packts: The number of packets that are sent over the network
/ Flags: Gives information about characteristics of the network. Possible values include _F_ (the AP is unconfigured. That means it uses well-known standard password(s) and IP range) and _D_ (DHCP traffic found)
/ IP Range: Specifies which IP addresses are used in a network
/ Size: The amount of data that is sent over a network

The frame on the right side named _Info_ gives general information about networks and data:

/ Ntwrks: The number of networks found
/ Pckets: The number of packets captured
/ Cryptd: The number of encrypted packets captured
/ Weak: The number of packets that contain a weak IV
/ Noise: The number of packets that are scrambled due to too high noise values
/ Discrd: The number of discarded packets
/ Elapsd: The time Kismet is up and running

The panel on the bottom of the page named _Status_ shows general information about Kismet and the logs created by the WIDS that is included in Kismet.

== WEP Cracking Tools

The following section gives a brief overview of tools which are capable of breaking a WEP key using different techniques.

#heading(level: 3, numbering: none, outlined: false)[AirSnort]

Probably one of the most famous WEP cracking tool for Windows and Linux is AirSnort. It was developed in 2001 by Jeremy Bruestle and Blake Hegerle, and implements the FMS attack.

#figure(
  image("graphics/Airsnort.png", width: 100%),
  caption: [The AirSnort GUI],
) <l-airsnort>

As @l-airsnort shows it is GUI based and offers several configuration options. To break a WEP key it is either possible to scan the network in real time (a cracking attempt is done each time ten weak IVs are captured) or load a pcap file with WEP encrypted packets. Additional options include the cracking breadth for 64 and 128 bit keys. The higher the breadth rate the more time it takes to break a WEP key but the higher the probability to find the correct one. A result in the _PW: Hex_ and _PW: ASCII_ column does not mean that the correct key was found. The documentation of AirSnort states that it uses a probabilistic approach which means that it tries to guess the correct key.

As it is shown in @wlan_sicherheit[p. 61f] AirSnort requires at least five million encrypted packets to break a WEP key. Depending on the captured data and the amount of weak IVs this value can also exceed the ten million mark.

In case a GPS device is available AirSnort also supports GPS. That offers the possibility to log the current position of the capturing entity.

#heading(level: 3, numbering: none, outlined: false)[Dwepcrack]

In 2002 a hacker named h1kari created a console based implementation of the Improved FMS attack and named it Dwepcrack which runs solely under Linux.

In addition to the Improved FMS attack it implements an advanced brute force attack which is especially well suited for 64 bit WEP keys. It manages to break down the key length from $2^40$ to $2^21$ possible keys. That makes it possible to perform a brute force attack in a reasonable amount of time. See also @wep_dead_1.

#heading(level: 3, numbering: none, outlined: false)[WepLab]

"WepLab is a tool designed to teach how WEP works, what different vulnerabilities it has, and how they can be used in practice to break a WEP protected wireless network. ... The author has tried to leave the source code as clear as possible, running away from optimizations that would obfuscate it." @weplab WepLab was developed in 2004 by Jose Ignacio Sanchez Martin alias Topo[LB] for Windows and Linux.

The main features of WepLab include:

- Analyse a pcap file and show relevant information like the number of captured packets and the number of unique IVs
- Perform a brute force attack to break a WEP key
- Perform a dictionary attack to break a WEP key
- Perform a statistical cryptanalysis attack to break a WEP key
- Capture packets from a wireless NIC
- Specify the length of the WEP key (64 or 128 bit)
- Specify the amount of keys tested using the `--perc` option (default: 50). The higher this value the higher the probability to find the correct key but the longer the search takes

#heading(level: 3, numbering: none, outlined: false)[Aircrack]

Aircrack is an implementation of the statistical cryptanalysis attack. @wep_dead_1 says that Aircrack provides the fastest and most effective attack currently available. It runs under Windows and Linux.

The main features of Aircrack include:

- Perform a statistical cryptanalysis attack to break a WEP key
- Specify the length of the WEP key (64 or 128 bit)
- Perform a dictionary attack on a WPA-PSK protected network
- The so called _fudge factor_ specifies the amount of keys tested. The higher this value the higher the probability to find the correct key but the longer the search takes

In addition to Aircrack some tools are delivered:

/ 802ether: Creates an unencrypted pcap file out of a WEP encrypted one by specifying the source and destination pcap file and the WEP key used
/ airodump: Captures packets of a wireless network and stores it in a pcap file. It is also possible to store only the unique IVs which are relevant for Aircrack
/ aireplay: Performs an active WEP attack in order to guess the WEP key by injecting previously captured encrypted packets

#heading(level: 3, numbering: none, outlined: false)[Tests and Results]

A test has shown (see Appendix @l-sec:aircrack_weplab) that Aircrack and Weplab require at least 800.000 packets containing approximately 341.000 unique IVs to break a 64 bit WEP key definitely.

An interesting detail concerning the test result is that in some cases it was possible for Aircrack to break the WEP by using only 100.000 packets containing 40.832 unique IVs to find the correct key. The calculation took from one to three minutes depending on the fudge factor.

WepLab also found the correct WEP key by using only 400.000 packets with 167.740 unique IVs in less than five minutes.

These results indicate that the success to break a 64 bit WEP key mainly depends on three things:

/ The amount of data: As shown in the test Aircrack and WepLab succeeded in breaking the key as soon as they had enough data (800.000 packets with 341.000 unique IVs).
/ The captured data itself: Both, Aircrack and WepLab, showed that it is possible to find the correct key in case less data is available.
/ Parameters: WepLab found a correct key when using the value 70 for the `--perc` parameter but did not find it when using the values 50 or 90.

Another test which is illustrated in @wlan_sicherheit[p. 207-210] presents a similar result. In this test it is shown that WepLab performs a little bit better than Aircrack when it comes to 64 bit WEP keys. Some exceptional results in the Aircrack test also show that the success to break a WEP key does not only depend on the amount of captured data.

== State of the Art WIDS

The following section gives a brief overview of wireless intrusion detection systems which are freely available on the Internet.

#heading(level: 3, numbering: none, outlined: false)[AirSnare]

AirSnare is a freely available WIDS for Windows. It was created in 2002 by Jay L. DeBoer and Thomas Bruinsma. @l-airsnare shows AirSnare at work.

#figure(
  image("graphics/Airsnare.png", width: 100%),
  caption: [The AirSnare GUI],
) <l-airsnare>

After starting AirSnare and choosing one wireless NIC that scans the traffic AirSnare displays information about MAC and IP addresses, and events that occurred. As soon as a new MAC address is found it is marked as _Unfriendly MAC Address_. All these clients are monitored. Each MAC address found can be set into the _Trusted MAC Address_ state so that no more alarms are triggered by that MAC address. In addition to the MAC addresses the IP address of each client is shown.

Another feature of AirSnare is that it displays DHCP requests captured. This is useful to identify malicious users. In case no DHCP server is available but a DHCP request is captured then it is possible that a malicious user tries to gather information about a network.

AirSnare also provides the _net send_ command for Windows which makes it possible to send a message to every client that runs the messenger service. This service is enabled by default.#footnote[For more information about the Windows messenger service see also http://support.microsoft.com/default.aspx?scid=KB;EN-US;168893]

In case an unfriendly MAC address is found an automatic mail can be sent to the network administrator to inform about uncontrolled behaviour in the network.

#heading(level: 3, numbering: none, outlined: false)[Wireless Snort]

Wireless Snort is the extension to the Snort program which is used in wired networks and works under Windows and Linux. This tool is written by Andrew Lockhard in 2003.

One aspect that makes Wireless Snort very powerful is the possibility to create custom rules. These rules are used to detect particular WLAN packets that are sent in the network.#footnote[An example for a rule could be to detect all association requests that come from a certain MAC address] Depending on the definition of the rule different actions can be taken. For more information about defining rules and using actions see @wireless_snort_rules. The most important actions include:

/ alert: This action generates an alert and then logs the packet
/ log: This action only logs the packet
/ pass: This action ignores the packet

In addition to defining custom rules Wireless Snort also provides the ability to detect DoS attacks and Netstumbler fingerprints.

#heading(level: 3, numbering: none, outlined: false)[Kismet]

As we have seen in the previous section Kismet is a powerful wireless scanner. In addition to that it can also be used as a WIDS. @l-kismetalerts shows all alerts Kismet can throw. The list of alerts and descriptions is also available in @kismet_readme. All events thrown are displayed in the _Status_ panel shown in @l-kismet.

#figure(
  table(
    columns: (150pt, 200pt),
    table.header([*Name*], [*Description*]),
    [Netstumbler probe requests], [In an attempt to disclose the SSID of a network, Netstumbler sends out unique packets],
    [Deauthenticate/Disassociate Flood], [By spoofing disassociate or deauthenticate packets, arbitrary (or all) clients can be disconnected from a network],
    [Lucent link test], [Lucent/Orinoco/Proxim/Agere provide site survey software. Kismet detects the usage of these tools],
    [Wellenreiter SSID brute force attempt], [Wellenreiter attempts to use a dictionary to brute-force a hidden SSID. Between each probe attempt it resets the card to probe for 'this\_is\_used\_for\_wellenreiter'],
    [Previously detected AP changing to a new channel], [Man-in-the-middle attacks attempt to direct users to a fake AP on another channel],
    [Broadcast disconnect/ deauthenticate], [Many attacks use a broadcast disassociate or deauthenticate to disconnect all users on a network, either to redirect them to a new fake network or do cause a denial of service or disclose a cloaked SSID],
    [SSID of 'airjack'], [The AirJack tool sets the initial SSID to 'airjack'],
    [Clients probing for networks, being accepted by that network, and continuing to probe for networks], ['Active' or 'Firmware' network scanning tools work by letting the card probe for any network and recording those that respond],
    [Traffic from a source within 10 seconds of a disassociation], [A host which legitimately disassociates or deauthenticates from a network should not be exchanging data immediately thereafter],
    [Probe response packet with 0 length SSID tagged parameter], [Many firmware versions from different manufacturers have a fatal error when they receive a probe response with a 0 length SSID tagged parameter],
    [Invalid BSS timestamps indicative of an access point being spoofed], [The BSS timestamp sent with beacons and some probe frames cannot be spoofed with standard firmware or drivers even when forging raw frames],
  ),
  caption: [WIDS alerts Kismet can throw],
) <l-kismetalerts>

Kismet can also be used as a distributed WIDS. It manages drones which send their captured data to a dedicated server which then checks for a possible threat.

#heading(level: 3, numbering: none, outlined: false)[WIDZ]

In 2003 Mark Osborne designed and implemented a tool named WIDZ. He says that the tool is only a _proof of concept_ to show insecurities in wireless networks. @widz_design It runs solely under Linux.

WIDZ detects basic attacks like rogue APs, active scanners and flood attacks. It is possible to create white and black lists of MAC addresses and a white list for SSIDs. Additionally, a user can create alert scripts that are run whenever WIDZ triggers an alarm.

According to @widz_design[p. 3f] WIDZ is divided into two different modules:

/ AP monitor: This module is capable of identifying bogus APs#footnote[See glossary] and unauthorised APs#footnote[See glossary]. Both types of attacks are identified by comparing simple text files that contain MAC addresses with the MAC addresses found

#pagebreak()

/ Traffic monitor: Since not all threats can be detected by managing text files this module deals with identifying other type of attacks. The most severe attacks that can be recognised by WIDZ are _probe monitoring_#footnote[Probe monitoring means detecting active scanners by searching for probe requests where the SSID is not set] and _flood detection_

#heading(level: 3, numbering: none, outlined: false)[Additional Remarks]

Despite the possibility to operate a WIDS that monitors a whole network there exists a problem that all tools presented have in common. A wireless network can use 11 different channels. In order to detect rogue APs#footnote[See glossary] it is necessary to monitor all channels at the same time. This can either be done by running a WIDS for every single channel which is an expensive solution or to use one single WIDS which performs channel hopping. The problem with the latter solution is that the WIDS might miss traffic that is sent during the periods it does not listen to a certain channel. In the worst case an attack is performed exactly at that time.

#heading(level: 3, numbering: none, outlined: false)[Conclusion]

@l-wids_compare shows a brief comparison of all Linux based WIDS presented above. This evaluation is taken and adopted from @wlan_sicherheit.

#figure(
  table(
    columns: (80pt, 80pt, 80pt, 80pt),
    table.header([*Type*], [*Wireless Snort*], [*Kismet*], [*WIDZ*]),
    [DoS], [yes], [yes], [yes],
    [Active attack], [yes], [yes], [yes],
    [Rogue AP], [no], [not automated], [yes],
    [Re-injection], [no], [no], [no],
    [Distributed], [yes], [yes], [no],
  ),
  caption: [Feature comparison of different WIDS],
) <l-wids_compare>

All WIDSs evaluated are freely available on the Internet and each of them has its advantages and drawbacks. Kismet and Wireless Snort seem to be very sophisticated because they also allow the creation of distributed systems with drones that collect data and send it to a server. Another advantage of Kismet is that the installation is easy and it can be used without handling difficult configuration files. On the other hand Wireless Snort allows the system to store the gathered information in a database. The actual decision which WIDS to choose depends on the needs of the network administrator.
