#pagebreak(weak: true)
#align(center + horizon)[
  #text(size: 28pt, weight: "bold")[Part: Fundamentals]
]
#pagebreak()

= Introduction

== Motivation and Goals

When using wireless technologies a network operator has to keep in mind that there exist several threats which can harm the network infrastructure. These threats range from users who break into a network to the breakdown of the whole network due to missing alerting systems.

As a counter measure systems are being developed which can track malicious users and abnormal traffic in the network. The major inconvenience of these systems is that most of them use static mechanisms. In other words they do not react to changes in the network behaviour like variations in the amount of data sent or the number of connected clients. In case such a system is set up initially with some thresholds and values that fit to the network it is almost impossible for the system to identify malicious users reliably after a period of time when the behaviour of the users changed.

The main goal of the underlying study is to show the feasibility and implementation of a hybrid wireless intrusion detection system which combines established intrusion detection techniques and a self learning system using a neural network. This system should be capable of identifying specific wireless flood attacks like association and disassociation floods. At the time the system is initialised it has no information about how a flood looks like. Therefore the system is not capable of identifying different flood attacks until the training phase is finished.

By using a self learning system it is possible to react to changes in the network characteristics automatically.

== Structure of this Document

The underlying study is divided into two parts:

/ 1. Fundamentals: Explains the required theoretical background to understand this work. First, an introduction of wireless networks using the IEEE 802.11 standard and its frame format is given. The next part discusses the process of scanning and infiltrating wireless networks. Additionally, possible ways to characterise intrusion detection systems are shown. Finally, neural networks are explained in detail to understand the implementation part of this work.
/ 2. Analysis and Implementation: Presents an overview of freely available wireless tools used for network scanning, like Kismet and Netstumbler. A short introduction to Aircrack and WepLab, which are programs to break WEP keys, is given. Finally, intrusion detection systems, like AirSnare and WIDZ, are discussed. The implementation part of this study shows design and implementation details of a hybrid wireless intrusion detection system containing a neural network. The obtained results of the system are shown and interpreted. This work ends with a discussion on how future work could look like.

= WLAN

== Definition

WLAN is the abbreviation of *W*ireless *L*ocal *A*rea *N*etwork and describes a network in which the communication between participants takes place over a wireless medium like radio frequency or infrared.

According to @80211wireless[p. 1-3], when focusing on the user of a wireless network there exist some advantages and new possibilities over wired networks. First and most important, since wireless means _no cables_ users can move around with their laptop or PDA in the range of an access point while staying connected to a network and without worrying about plugging wires.

An advantage for the operator of a wireless network is that no cables have to be laid. This point is especially important for buildings that are under historical preservation protection or where wiring is very expensive. Another example is a company building that is split up into two locations by a road. In this case running cables can be a critical and expensive issue.

Although vendors claim that their IEEE 802.11g WLAN cards operate on up to 54 MBit/s such high transfer rates can hardly be accomplished. These rates have to be considered as gross values. This speed is only possible when sitting approximately ten centimetres in front of the access point. Due to interferences the net bandwidth that a user gets when using a wireless network lies somewhere between 1 MBit/s and 20 MBit/s @wlan_grundlagen.

Additionally, there exist some problems that have to be dealt with. Since in a wireless medium there exist no cables with a start and an end, packets propagate freely through the air. This makes it easy to intercept data transfer. Even when using encryption techniques like WEP WLAN is still not secure enough for high confidential data transfers. For a cracker#footnote[It is important to differentiate between _hacker_ and _cracker_ because the term _hacker_ is misused very often. Generally a hacker does not want to harm the network whereas the cracker does. For a detailed definition see @vrijschrift] it is a matter of minutes to hours to break a WEP key successfully using tools that are freely available on the Internet.

== The 802.11 Standard

"IEEE 802.11 is the most common standard for wireless local area networks." @80211mostcommon. Since the beginning of the development of wireless networks a lot of different standards arose and are still evolving. The IEEE (Institute of Electrical and Electronics Engineers) takes care for the development of these.

@l-80211 shows a list with the most common wireless standards used at the time this document was written.

#figure(
  table(
    columns: (auto, auto, auto, 150pt),
    table.header([*Standard*], [*Max. Speed*], [*Frequency*], []),
    [802.11], [2 MBit/s], [2.4 Ghz], [Developed in 1997 this was the first PHY standard and in addition describes the whole 802.11 protocol family],
    [802.11a], [54 MBit/s], [5 Ghz], [The second PHY developed in 1999 and released in 2000. Products that use this standard are used rarely because of their high price. Besides, 802.11a is incompatible to the much cheaper 802.11b standard],
    [802.11b], [11 MBit/s], [2.4 Ghz], [Third PHY standard developed in 1999. When wireless networks became popular this was the most common standard because wireless NICs that use this standard are inexpensive compared to products that implement the 802.11a standard],
    [802.11g], [54 MBit/s], [2.4 Ghz], [Developed in 2003. This standard is compatible to 802.11b and currently becomes most widely used because it is faster than 802.11b],
    [802.11n], [540 MBit/s], [2.4 Ghz], [In development since 2004. The main goal of this standard is to raise the maximum throughput],
  ),
  caption: [The most important IEEE 802.11 standards @80211abgn],
) <l-80211>

There exist other standards like 802.11i which is developed to overcome the drawbacks of security in 802.11. Another example is 802.11j which is an extension to 802.11a to stay conform with Japanese radio emission regulations. For a complete list on all available standards see @80211wireless[p. 10].

The 802.11 standard defines only the two lowest layers of the ISO/OSI seven layer protocol stack. See also @80211tech. @l-80211standard shows the components of the 802.11 standard.

#figure(
  image("graphics/80211_protocol_stack.png", width: 90%),
  caption: [Layer one and two of the ISO/OSI protocol stack],
) <l-80211standard>

/ Data Link Layer: The MAC sublayer is responsible for the access to the wireless medium. Possible access methods are CSMA/CA (Carrier Sense Multiple Access using Collision Avoidance), CSMA with RTS/CTS (Request To Send/Clear To Send) or PCF (Point Coordination Function).
/ Physical Layer: This layer is responsible for transferring bits from one wireless device to another. IEEE 802.11 defines infrared and radio frequency communication. The way how the frequencies are used are either defined in the FHSS (Frequency Hopping Spread Spectrum), the DSSS (Direct Sequence Spread Spectrum) or the OFDM (Orthogonal Frequency Division Multiplexing). For a more detailed explanation see also @mobile_computing[p. 85-87].

== Types and Architectures

As with the possibility to create networks without using any cables and the fast development of wireless networks there exists the need to create networks that serve specific purposes like setting up a wireless network quickly or serving a lot of users. In general, there exist two major types of networks, _independent BSS_ and _infrastructure BSS_, whereas the latter has several subtypes which are described briefly.

==== Independent BSS (IBSS)

Often these networks are also called _ad hoc networks_ because they can be set up very quickly using simple WLAN cards without the need of any additional hardware. This type of network is set up for specific purposes like meetings, conferences or LAN parties and exists only over a short period of time. All participants communicate directly with each other. As @l-ibss shows there is no intermediate station that is responsible for managing the connections of all stations like it is the case in infrastructure networks.

#figure(
  image("graphics/IBSS.png", width: 50%),
  caption: [An IBSS. All clients are connected directly],
) <l-ibss>

==== Infrastructure BSS

The difference between an IBSS and an infrastructure BSS is that the latter uses an access point which serves as a central station that handles associations and data for all participants and is "a bridge to the wired network" @wildpacket[p. 5]. @l-infrastructurebss shows a sample infrastructure BSS configuration. Whenever a participant of the network wants to send data to another host it first sends the data to the access point which then forwards the data to the desired destination. An infrastructure BSS has some advantages over a simple ad hoc network:

- Due to the fact that every station sends the data packet to its associated access point which then forwards it to its destination the covered area of the wireless network is specified by the access point and not by the participants
- In case a station is in power saving mode the access point can buffer the received packets for the destined client. As soon as the sleeping station comes up again the access point can send the data
- In an infrastructure BSS stations first have to associate with the network in order to be able to send and receive data to and from the network. The access point can accept or deny the association attempt of a station based on parameters that can be set in the access point. For example most access points have ACLs which are used to block certain MAC addresses

#figure(
  image("graphics/InfrastructureBSS.png", width: 50%),
  caption: [An infrastructure BSS. The access point manages all stations],
) <l-infrastructurebss>

==== Extended Service Set

As the covered area in a simple infrastructure BSS is limited by the power of one single access point an extended service area can cover larger areas by using a lot of access points that are linked together. By giving every single access point the same SSID huge wireless networks can be created. A distributed system is responsible for delivering the data from one access point to another. This network topology offers the possibility for stations to move around and change the associated access point while staying connected. The wireless card takes care of connecting to the access point with the highest signal strength.#footnote[The access point with the highest signal strength is normally the nearest one]

==== Multi-BSS or "Virtual Access Points"

Some access points offer the possibility to create two or more BSS, each with different privileges. For example in a company there would exist a network with the name "company" that would be used by the people working in the company. Additionally, there would exist another network with the name "guest" which could be used by the people that do not work in the company. Both networks would be managed by the same access point. The network with the name "company" could be secured using WEP or WPA and could grant access to privileged users only. The network "guest" would offer access to every person who has a WLAN card but the access to the network should be more restricted. As a consequence the access point would handle the requests coming from a certain station differently. It would either forward to the internal company network or would give only access to the guest network @80211wireless[p. 19].

#pagebreak()

== Specification of WLAN Frames

Each single frame sent in a wireless network has a certain structure. The general format of an IEEE 802.11 frame and a description including the size of each field in bytes is shown in @l-frameformat. A frame is transferred from the left to the right with respect to time.

#figure(
  image("graphics/GeneralMACformat.png", width: 100%),
  caption: [Format of an IEEE 802.11 WLAN packet. Sizes in byte],
) <l-frameformat>

==== Frame Control

The Frame Control part of each packet is split up into several subfields as shown below in @l-framecontrol.

#figure(
  image("graphics/FrameControl.png", width: 75%),
  caption: [Frame Control of an IEEE 802.11 WLAN packet. Sizes in bit],
) <l-framecontrol>

The value of the *_Protocol_* field indicates the version of the 802.11 MAC. Until now, there exists one version with the value 00b.

The *_Type_* and *_Subtype_* fields of the Frame Control indicate what kind of information is sent over the network. There exist three types of frames named _Management frames_ (responsible for authentication, association and disassociation of clients, synchronisation, etc.), _Control frames_ (responsible for RTS/CTS procedure, acknowledgements of received frames, power saving of access points, etc.), and _Data frames_ (responsible for data, QoS, etc.). These two fields play a major role when implementing a wireless tool because based on this information the program has to interpret the data following the Frame Control field. See @80211standard[p. 36] for a list with all possible values and their meaning.

The *_to DS_* and *_from DS_* fields indicate whether data is coming from or going to a distributed system. @l-tofromDS shows detailed information about the different ways these values can be set and their meaning. See also @80211wireless[p. 49].

#figure(
  table(
    columns: (auto, 100pt, 100pt),
    [], [*to DS = 0b*], [*to DS = 1b*],
    [*from DS = 0b*], [All frames in an IBSS], [Data frames sent from a station to the DS],
    [*from DS = 1b*], [Data frames coming from the DS], [Frames on a WDS (wireless bridge)],
  ),
  caption: [Possible settings for the _to DS_ and _from DS_ fields],
) <l-tofromDS>

In case the *_More fragments_* bit is set to 1b the current frame is fragmented. Each fragmented frame, excluding the last one, set it to 1b. The most common case is that no fragmentation is used, so this field would be set to 0b.

In case frames have to be transmitted more than once (for instance when a frame gets lost) the value of the *_Retry_* field is set to 1b. Otherwise it has the value of 0b.

The *_Power management_* field tells whether a mobile station is in power saving mode.

The *_More Data_* field indicates whether the access point buffers data for a sleeping station which is in power saving mode.

In case a frame is protected by an upper layer protocol (for instance WEP) the *_Protected_* bit is set to 1b. This is necessary because in case the frame is encrypted its structure might change a little bit.

In case frames have to be transmitted as a sequence, the *_Order_* field is set to 1b. It is important to note that setting this bit to 1b means more computation overhead for each WLAN card involved.

==== Duration/ID

This field can have different meanings. First, it can be an indication for how long the wireless medium will be reserved for a transaction of frames. Next, it can be used for telling all stations that a contention free period has started. Finally, it can also be used by the stations to tell the access point to send buffered frames when a station leaves its power saving mode.

==== Address fields (Address 1 to 4)

Depending on the values set in the *_to DS_* and *_from DS_* field in the Frame Control part three or four address fields can be set. The meaning of the different address fields is as follows: Address 1 is the receiver of a frame, Address 2 the transmitter of a frame, Address 3 is used for filtering depending on the receiver and type of the network and Address 4 is used only in wireless bridges and is not discussed here. Each address is a 48 bit MAC address identifier.

In case all bits of an address are set to 1b (FF:FF:FF:FF:FF:FF) then it is a broadcast address which means that the frame is sent to every station in the network.

In case it starts with a 0b (for instance 00:03:4A:72:FC:31) then it is a unicast address which points to one single station.

There exist other types of addresses which can be viewed at @mac_meaning.

==== Sequence Control

"This 16-bit field is used for both defragmentation and discarding duplicate frames. It is composed of a 4-bit fragment number field and a 12-bit sequence number field" @80211wireless[p. 52]. Each frame has an own sequence number. In case a frame is fragmented the fragment number is incremented by one but the sequence field stays the same.

==== Frame Body

This field contains the payload of a frame.

==== Frame Check Sequence

A station can check the received frame for its correctness. The check is done by using a CRC. All fields of the frame are included in the check. The CRC is done before a frame is sent from the sending station and before it is processed by the receiving station.

== Hidden Node Problem <l-sec:hidden_node_problem>

In a wireless network it is possible that not every station is in range of all others. As it is shown in @l-hiddennode it is possible that one client (the access point in this example) can be in range of station 1 and station 2 but station 1 may not be in sending range of station 2. This means that it is not possible for station 1 to determine whether station 2 is currently sending or not and vice versa. This is called the _hidden node problem_.

#figure(
  image("graphics/HiddenNode.png", width: 50%),
  caption: [The hidden node problem],
) <l-hiddennode>

To overcome this problem when using a wireless medium CSMA with RTS/CTS is used to make sure that the medium is idle. By using a four way handshake in which particular frames are exchanged all participants of a wireless network get informed whether the medium is idle and possible for a transfer or not. This handshake is done by sending RTS (Request To Send) and CTS (Clear To Send) frames. @l-rtscts was taken from @80211wireless[p. 36] and illustrates the process of how a sender and receiver communicate RTS and CTS frames before sending data and its acknowledgement.

#figure(
  image("graphics/RtsCtsHandshake.png", width: 65%),
  caption: [The RTS/CTS handshake],
) <l-rtscts>

Since the fact that this four way handshake requires a lot of additional frames sent over the wireless medium it is only used in large company environments where the probability of interfering sending stations is more severe. In smaller environments the handshake procedure is not performed and the data is simply sent without worrying about the hidden node problem. If simultaneous transmissions happen then the frame, on which the collision happened, is simply resent.

== Producing Traffic

Before a station can send and receive data in a wireless network a client has to go through the authentication and the association process. According to @authassoc the process of connecting to a wireless network is split up into three phases.

==== Phase 1: Probing

A station in this phase is neither authenticated nor associated. It checks its environment for possible access points which it can connect to.

==== Phase 2: Authentication

After the station found an access point it authenticates itself to the network. There exist two ways on how to do this. If the access point uses _open_ authentication, a new station can associate with an access point without taking any additional steps. The other possibility is _shared_ authentication. Using this technique some encryption mechanism like WEP is used. A client has to provide a secret key to authenticate to a network successfully.

==== Phase 3: Association

After a station was authenticated successfully it has to associate with the access point. The association of a new station is always initiated by the station. In order to associate with an access point it is necessary to determine the SSID, which is the name of a wireless network. To simplify the location of wireless networks an access point can periodically send out beacon frames which are received by all stations in range. The information kept in beacon frames also includes the SSID. A station collects a beacon frame, extracts the SSID and sends an association request to the access point. If the wireless network is in _hidden mode_, it does not send any beacon frames which could be collected by clients. In this mode a new client of the network has to know the SSID in advance.

After a successful association a station can send and receive data to and from the wireless network.

= Network Scanning

== Introduction

In order to be able to infiltrate a wireless network it is necessary to gather information about the network and its properties. This can either be done by being a legitimate client and knowing a lot of things about the network beforehand or by using wireless network scanners which scan the network and display the information needed. As described later wireless tools present information about a network to the user. Useful information which can be gathered by a simple wireless scanner include:

/ SSID: In case of a cloaked network it is not possible without the knowledge of the SSID to associate with a network. SSIDs can be received in two ways. One way is to collect beacon frames which are automatically sent out by an access point. So the only thing a cracker has to do is to wait for an incoming beacon frame and read out its SSID information. If the access point does not send out beacon frames, a cracker has to wait for a probe request of a new legitimate station which includes the SSID information of the network it wants to connect to.
/ DHCP information: In case a wireless network is found, either by receiving a beacon frame or a probe response in a cloaked network, the next step is to find out whether there exists a DHCP server in the network. If there exists one or more DHCP server in the network, a cracker simply broadcasts a DHCP discover request to the network and receives all information that is required. Although it is easier for the network administrator to set up a DHCP server than assigning static IP addresses it is critical to use DHCP because the person who infiltrates the network probably knows about the simplicity of using the DHCP service.
/ IP information: For a successful login it is necessary to know on which IP addresses a network operates and the address of the gateway. This can be done by capturing data frames that contain IP information like ARP, TCP or UDP frames.
/ MAC addresses: Each single network card has its worldwide unique MAC address. By configuring the access point to accept only association attempts from devices with MAC addresses that are known it is impossible for an intruder to enter a wireless network in case the MAC address of the NIC owned by the intruder is not spoofed. MAC addresses can be read out of every single packet that is sent over the network.
/ Encryption: Most access points still use WEP encryption. After the RC4 algorithm was cracked by Scott Fluhrer, Itsik Mantin and Adi Shamir (see @rc4weak) a new encryption method was developed (WPA) and should be used in a wireless network environment because it is still considered secure.
/ Uptime: By knowing the period of time an access point is online a cracker can find out whether the access point is disabled in the nights or whether it runs over weeks without being set offline which indicates a lack of security. In general it is not common that a network operator monitors the networks during the nights. The uptime information is located in a beacon frame.
/ Signal strength: @signal_strength describes it as "a signal ... that indicates the strength of the incoming (received) signal in a receiver". The higher the signal strength the faster the connection. When sitting close to an access point the probability to receive certain frames is much higher than sitting at the edge of its covered area. This information is located in the private headers of a packet and can only be read out of certain chipsets like Prism WLAN cards.

== Active versus Passive Scanning <l-sec:active_passive_scanning>

The first way of scanning a wireless network is named *_active scanning_*. By using packet injection an active wireless network scanning software sends probe requests leaving the SSID field empty to the wireless medium. In case an access point is not in hidden mode it responds with a probe response including the SSID. The problem of this approach is that networks which are in hidden mode can not be found and so stay unknown for the user. Another drawback of this method is that packets have to be sent and as a consequence information about the software and the scanning client is revealed. Information that can be gathered includes the MAC address which can identify a wireless network card uniquely, its signal strength or even the software used. The latter piece of information can be retrieved by using fingerprinting techniques. According to @triangulation it is even possible to physically locate active scanners by using triangulation.

When using *_passive scanning_* the wireless NIC is first set into _monitor mode_#footnote[It is also called _promiscuous mode_ or _rfmon_. That means a card can be put in a mode in which it can capture all packets that travel through the air. Even those packets are captured that are not destined for the scanning NIC.] and then scans the air. That means that these tools can also find hidden networks because they can capture traffic from another station to an access point. On the other hand it is not possible with standard hardware to send out any packets. As a consequence it is only possible to scan a network but not to inject packets. Tools using the passive scanning technique can neither be located nor identified.

== Wardriving

"Wardriving, also called access point mapping, is the act of locating and possibly exploiting connections to wireless local area networks while driving around a city or elsewhere." @wardrivingdef

In order not to confuse wardriving with the original meaning of the word _war_, today it stands for _Wireless Access Revolution_. The second part of the term indicates the type of transportation.

Beside wardriving there exist a lot of modifications like _warwalking_ (walking around with a laptop), _wartraming_ (scanning networks inside a tramway), _warbiking_ (scanning networks while riding a bike), etc. Due to the different possibilities to move around the act of searching for wireless networks is sometimes named _warXing_.

The topic wardriving came up around the year 2000. Peter Shipley claims being the inventor of wardriving. See @shipley for a brief portrait. He and others were the first persons who pointed the finger on the insecurities of wireless networks and started to create scripts that automated scanning for wireless networks. The initial idea was to map positions of wireless networks on maps to show how many of them are open or secured by WEP.

From these days on a lot of different tools were developed which became more and more powerful and people started to misuse wireless networks they found for their own purpose.

== Warchalking

"The act of making chalk marks on outdoor surfaces (walls, sidewalks, buildings, sign posts, trees) to indicate the existence of an open wireless network connection, usually offering an Internet connection so that others can benefit from the free wireless access." @warchalkingdef @l-warchalk shows a table with possible warchalking signs.

#figure(
  image("graphics/Warchalk.png", width: 45%),
  caption: [Warchalking signs @warchalkingimg],
) <l-warchalk>

The symbols on the right side indicate the sign which is painted on a wall to inform about a particular type of network. The information put in each symbol tells enough about the effort that is necessary to gain access to a network. Later in this work it is shown that an open network is much easier to infiltrate than a network that is WEP protected.

== Equipment

The standard equipment of a wardriver typically consists of a laptop and a wireless network card. Often a GPS antenna is also used to generate maps showing all access points found including additional information like the signal strength or encryption information. Due to the fact that the coverage of a wireless NIC is limited some wireless cards have the capability to add external antennas to improve their receiving range. As a result more wireless networks can be found.

Depending on the way networks are scanned there exist different types of operating systems and chipsets of wireless NICs which have different capabilities.

For a normal scan of a wireless network it is sufficient to use any wireless NIC and Windows as the operating system. There is no need for special software because Windows has a built in wireless network scanner. Besides, there exist powerful scanning software for this OS.

A lot of wireless network scanners are available for Linux and monitor mode is supported for a large range of chipsets.#footnote[See #link("http://www.linux-wlan.org/docs/wlan_adapters.html.gz") for a complete list with all vendors and chipsets of different wireless NICs.] Common chipsets include Prism, Orinoco and Aironet because the usage of their monitor mode is easy and a lot of tools written in Linux can set and unset the monitor mode automatically.

== Ethics

According to @wardrivingforms the actual goal of a wardriver can generally be classified in three different groups:

+ The first group simply wants to create maps for cartographic and statistical purposes
+ The second group makes fun out of finding wireless networks and practices warchalking to inform other wardrivers of available networks
+ The third group is the most dangerous one. These people search, find and misuse wireless networks for their own purpose. In Austria this group is acting against the law and can be punished for its actions (see the following section @l-sec:laws for details)

== Laws <l-sec:laws>

As companies and individuals begin to realise that wardriving costs companies millions of Euros every year#footnote[An article available at http://www.securitymanagement.com/library/001493.html speaks of approximately 70 million dollars a year] it becomes necessary to create laws that prevent wardriving. The biggest problem to create such laws is that computer industry is a very fast evolving area of science compared to law and legislation which is a slow process. New laws have to be discussed and validated which takes a lot of time. Nevertheless in august 2003 a new communication law passed in Austria.

The law says that it is prohibited to listen in, eavesdrop, record or intercept communicated messages as well as the transfer of scanned data to third persons. In case someone receives messages that are not intended to be received by this person then this data has to be deleted immediately.#footnote[BG BGBl. I 2003/70 § 93 section 3, 4]

On the other hand the operators of wireless networks are addressed. It is to the same amount illegal to operate a network that is insecure. The law says that an operator has to take care of the data protection of all users using a wireless network. That means an operator has to make arrangements for anyone using the network so that an abuse is not possible. The operator of an insecure network can be charged with up to 4000 Euro.#footnote[BG BGBl. I 2003/70 § 78 section 2]

= Wireless Intrusion Detection

== Definition <l-sec:wids_definition>

An _intrusion detection system_ (IDS) is a piece of software that knows how to detect intrusion attempts and unusual behaviour in a network. It possibly performs counter actions on a specific user who infiltrates the network. For a more detailed definition see also @idsdef.

The underlying study discusses only _network based systems_ and ignores _host based systems_ since they are not relevant for this work.

== Passive versus Reactive Systems

A way to classify different IDS is to distinguish the reaction that is taken when an intrusion attempt of a user is detected. In a passive system no active reaction is taken. The administrator just gets informed about a malicious user and logs are created. In a reactive system the IDS responds to an intrusion attempt by issuing active counter measures. For instance it could log off the user or update the firewall to lock the malicious user out of the network.

== Signature versus Anomaly Based Systems <l-sec:sig_anom_ids>

As shown in @idsdef IDSs can also be classified by focusing on the techniques used to detect abnormal behaviour. There exist two different approaches on detecting a misuse:

/ Signature based: A signature based system contains a database with signatures of known attacks on a network. Whenever frames are received the system compares the signatures stored in the database with the signature created for the received frames. If the signatures are equivalent, an attack is detected and an alert is created. A signature is either a single action (i.e.: a login to a system) or a sequence of actions.

  "The advantage of this method is that there are few false alarms, or false positives, when attacks are detected" @wids[p. 9].

  On the other hand the whole system is only as good as the underlying database. If the status of the signature database is outdated, the system is not able to detect new attacks since these signatures are not available. Besides, variations of known attacks can not be discovered since their signature differs from the original one.

/ Anomaly based: In an anomaly based system a network administrator defines parameters that define the _normal behaviour_ of the network. For example in order to detect flood attacks thresholds which identify the maximum number of packets in a particular period of time can be set. Another example are white lists of known clients which are allowed to use a network. In case a client with an unknown MAC address appears it is probably a malicious user. The advantage is that unknown attacks can be detected. On the other hand the quality of the system relies on the values defined by the administrator. Very often more false alarms are created when using an anomaly based system than when using a signature based system @IDS_anomaly_false_alarms[p. 3].

== Structure of an IDS <l-sec:ids_structure>

Different IDS provide the user with a varying amount of features. Despite the big differences in capabilities of each IDS the basic structure stays the same. It is generally divided into four parts described below. See @wids_schreiber for more information.

+ The *_data gathering component_* is responsible for collecting data that is transferred over the network. This component is called _sensor_ or _drone_. It transmits the received data to the data processing component
+ The *_data processing component_* is the core of an IDS. It compares all received data and tries to detect attacks
+ The *_data storage component_* stores the data that was already processed and makes it available at a later time
+ If an attack is discovered, the *_response component_* performs counter measures like logging off a user

== Security Aspects

According to @wids_schreiber an IDS is an interesting goal for a cracker. As a consequence the IDS itself has to be protected from the following threats:

/ DoS attack: Since the IDS scans and stores packets that are relevant for the detection of an attack a cracker could send out large amounts of these packets to bring the IDS down. A counter measure to this threat is to use a buffer which overflows when it is full. The data processing component takes the data from this buffer instead from the data gathering component directly. The drawback of the buffer is that at the time the buffer is full the system can not respond to attacks that are currently running
/ Direct attack: Since programs (especially those written in C/C++ where pointers are used) are vulnerable to buffer overflow attacks the IDS can be brought down by such an attack. The difference to the DoS attack described above is that the direct attack tries to exploit the weaknesses in the code of the program. The DoS attack tries to harm the system based on its function, namely intrusion detection
/ Communication channel attack: This attack deals with disturbing the communication between the IDS and its infrastructure. An example is a cracker who manages it to bring down the mail server which sends out alerts and warnings to the network administrator
/ Subterfuge attack: "In a subterfuge attack, an attacker attempts to mislead the monitor as to the meaning of the traffic it analyzes" @subterfuge_attack. For instance in an anomaly based system the cracker performs the attack very slowly so that the IDS does not recognise it

= Neural Networks

== Introduction

This section gives an overview of neural networks. First, the difference between biological and artificial neural networks (ANN) is explained. Next, artificial neural networks are explained in more detail by showing different learning methods. Additionally, some learning algorithms are shown like the principles of _delta rule learning_ and _backpropagation learning_.

== Definition

@essence[p. 156] states that a "neural network consists of many simple processing units (or neurons) connected together. The behaviour of each neuron is very simple but together a collection of neurons can have sophisticated behaviour".

== Biological Neural Networks

The basis of an artificial neural network is the human brain. A brain consists of billions of simple processing units called neurons. Each neuron is connected with thousands of other neurons over axons and dendrites. @l-singleneuron shows one single neuron. The communication in a neural network takes place over the connections named axons (output of the neuron) and dendrites (input to the neuron). Whenever the received input stimulation exceeds a certain threshold the neuron becomes activated, fires and gives its output to its neighbouring neurons. The receiving neuron again checks for the threshold and so on.

#figure(
  image("graphics/HumanNeuron.png", width: 75%),
  caption: [One neuron of the human brain],
) <l-singleneuron>

The learning process of the human brain depends on the synapses. When a synapse receives input it releases certain chemicals in order to forward to the next input. Depending on the amount of chemicals released the received stimulation is forwarded by a certain strength. Learning is done by adjusting this amount @essence[p. 157]. As described in the next section in an artificial network this amount of chemicals can be illustrated by using weights between neurons.

== Artificial Neural Networks

The idea of creating neural networks with weighted connections came up around 1960 when Frank Rosenblatt published his paper _Perceptron_. He was one of the pioneers who developed and coined the term _perceptron_ which became the basis for today's neural networks. For detailed information about Frank Rosenblatt see also @rosenblatt and @neuralnetworks[p. 55].

==== Capabilities of ANNs

An ANN can be used for complex classification tasks and will most likely find good solutions for a large range of problems. Besides, after it is trained to solve a specific problem it can find solutions for other similar problems. The following list shows some areas where ANNs can be used. See also @nn_applications.

- Pattern recognition (characters, images, etc.)
- Language processing
- Complex logical operations
- Data compression
- Optimisation
- Simulation

==== Drawbacks of ANNs

ANNs suffer from some drawbacks. See also @nn_limitations.

- The quality of the results depends on the features chosen to train and use the network and the input values
- The weights of a network store the information implicitly. That means it is not possible to understand the values of the weights in a network
- The processing time needed to solve a problem grows as the problem size grows

== Activation Functions <l-sec:activation>

The activation function of a neural network describes how the output of a neuron is calculated. The most common ones used are described in the following section @nn_actfct.

/ Hard limiter: This function is described mathematically as

  $ f(x) = cases(
    1 "if" x >= 0,
    0 "otherwise",
  ) $

  It says that every time the argument $x$ of the function $f(x)$ is greater or equal to zero the output of the neuron is $1$. Otherwise it is $0$. See also @pattern[p. 178].

/ Identity: This function is described as

  $ y = C x $

  where $C$ is a constant and is mostly 1. The derivative is simply $C$.

/ Sigmoid: This function is described as

  $ y = 1 / (1 + exp(-a x)) $

  where $a$ is a value that changes the shape of the sigmoid function. The higher this value, the more it looks like the hard limiter function. The output of this function lies always between $0$ and $1$. The derivative is $y * (1 - y)$. See also @neuralnetworks[p. 149f] and @pattern[p. 184].

@l-activation shows all activation functions in one graph. The sigmoid function uses the value $10$ for the variable $a$.

#figure(
  image("graphics/Activation.png", width: 55%),
  caption: [A graph that shows all activation functions presented],
) <l-activation>

== Perceptron <l-sec:perceptron>

As described in @pattern[p. 178] @l-perceptron shows an idealised perceptron. It consists of input values $x_1, ..., x_n$, their respective weights $w_1, ..., w_n$ and an output $c$.

#figure(
  image("graphics/Perceptron.png", width: 55%),
  caption: [An idealised perceptron],
) <l-perceptron>

Whenever the perceptron receives input values on its input nodes the values are multiplied with the respective weight and all results are summed afterwards. This process can be shown as

$ c = f(z) $

where

$ z = sum_(i=1)^n w_i x_i $

After $z$ is calculated it is given to $f(z)$ which is the activation function of the perceptron. The output of this function is the output of the perceptron. In case the desired output can either be true or false (1 or 0 respectively) this is a hard limiter function as described in @l-sec:activation.

== Learning Methods

Learning in an ANN can be done in two different ways. The method used depends on the problem that needs to be solved.

/ Supervised: When using _supervised learning_ techniques the desired output is available. @l-logicaland shows an example of possible input values that are given to the ANN ($x_0$ and $x_1$) and the desired output $o$.

  #figure(
    table(
      columns: (auto, auto, auto),
      [$bold(x_0)$], [$bold(x_1)$], [$bold(o)$],
      [0], [0], [0],
      [0], [1], [0],
      [1], [0], [0],
      [1], [1], [1],
    ),
    caption: [The logical AND operation],
  ) <l-logicaland>

  In order to learn the logical AND operation it suffices to use a simple perceptron as shown in @l-sec:perceptron. At the time values are attached to the input nodes they are propagated through the net and the result is compared with the desired output. As we will see later depending on the learning algorithm the weights in the network are adjusted using different methods.

/ Unsupervised: The other possibility to learn is _unsupervised learning_. When using this technique the desired output is not available and the resulting output of the trained network can not be predicted. This type of networks is not discussed in this work.

== Bias <l-sec:bias>

As we will see in the next section learning in a neural network depends on adjusting the weights. Since it is possible that all input values from $x_1, ..., x_n$ are zero and as a consequence no learning would take place $x_0$ is introduced (see @l-perceptron). $x_0$ is a pseudo input which is also called a bias. It is responsible for keeping the result of the summation above zero so that learning takes place even though all other input values are zero.

As a consequence the formula $z = sum_(i=1)^n w_i x_i$ shown in @l-sec:perceptron has to be modified when learning takes place. The resulting formula looks as follows:

$ z = sum_(i=1)^n w_i x_i + w_0 $

== Learning Algorithms

The learning success in an ANN depends mainly on adjusting the weights between nodes.#footnote[Other parameters also influence the learning progress. These parameters include the number of nodes in a network or the chosen learning rate which is introduced in the following section] Depending on the method chosen to modify the weights in a network it takes a different amount of time to learn something successfully.

=== Delta Learning <l-sec:delta_learning>

The delta learning rule computes the new weight depending on the difference between the desired and the calculated output of the network.

The following formula shows how the weights in the delta rule are updated

where

- $w_p (t+1)$ is the new weight between two neurons
- $w_p (t)$ is the old weight between the same two neurons
- $rho$ is the learning rate
- $delta_p (i)$ is the error value calculated by the following formula
  $ delta_p (i) = [c_p (i) - o_p (i)] f'(z_p (i)) $
  where $o_p (i)$ is the desired output, $f'$ is the derivative of the activation function, "$z_p (i)$ is the weighted sum of the inputs to the $p^"th"$ output neuron" @pattern and $c_p (i)$ is the calculated output using the formula already described in @l-sec:perceptron and @l-sec:bias:
  $ c_p = f(sum_(i=1)^n w_i x_i + w_0) $
- $x(i)$ is the $i^"th"$ value of the input vector

The following learning algorithm was taken and adopted from @pattern[p. 186] and shows one learning step in a single layer network when using the delta rule:

#align(center)[
  #box(stroke: 1pt, inset: 1em, width: 255pt)[
    + Initialise weight vectors $w_p, p=1,...,k$
    + Present $x(i)$ to the network
    + Calculate $c_p (i)$ and $delta_p (i)$ for each neuron as shown above
    + Update weight vectors as shown above
  ]
]

@l-delta_learning_ex shows an example of delta learning using a learning rate $rho$ of $0.25$ and the identity as activation function. The weights are initialised randomly with the values 0.3 and 0.6. @l-delta_ex_pattern displays the input pattern to be learnt.

#figure(
  table(
    columns: (auto, auto, auto),
    [$bold(x_0)$], [$bold(x_1)$], [$bold(o)$],
    [0], [1], [1],
    [1], [0], [0],
  ),
  caption: [An example pattern to be learnt by the perceptron],
) <l-delta_ex_pattern>

As shown in @l-delta_learning_ex the only thing that needs to be calculated is $delta_p (i)$. First, the input is given to the network. As soon as $delta_p (i)$ is calculated all needed values are inserted in. Finally, the next input vector is processed using the updated weight values.

#figure(
  image("graphics/show_delta.png", width: 80%),
  caption: [An example of using the delta learning rule],
) <l-delta_learning_ex>

=== Backpropagation Learning <l-sec:backpropagation>

A backpropagation network consists of one input layer, at least one hidden layer and one output layer. So that it is possible to update all weights in the network, the weight updating formula shown in @l-sec:delta_learning needs to be extended to

$ w_p^q (t+1) = w_p^q (t) - rho [delta_p^q (i) c^(q-1)(i)] $

assuming that $c^0 (i) = x(i)$. Additionally, the computation of the error value has to be divided into two parts. The calculation of the error value for the output layer is

$ delta_p^L (i) = [c_p (i) - o_p (i)] f'(z_p (i)) $

and the calculation of the error values for the hidden layer(s) is

$ delta_p^q (i) = [sum_(s=1)^(k_(q+1)) delta^(q+1) (i) w^(q+1)] f'(z_p (i)) $

The following algorithm shows how learning works when using backpropagation. See also @backpropagation, @back-propagation and @pattern[p. 187] for more information.

#align(center)[
  #box(stroke: 1pt, inset: 1em, width: 300pt)[
    + Initialise weight vectors $w_p, p=1,...,k_q, q=1,...,L$
    + Present $x(i)$ to the network
    + Calculate $c_p^L (i), p=1,...k_L$ as shown in @l-sec:delta_learning
    + Calculate $delta_p^L, p=1,...,k_L$
    + For $q = L - 1$ to $1$ do
      + Calculate the error value $delta_p^q, p=1,...,k_q$
    + Update weight vectors
  ]
]

where

- $L$ is the number of layers in the network
- $k_q$ is the number of nodes in the $q^"th"$ layer
- $x(i)$ is the input vector
- $c_p^q (i)$ is the calculated output value of the $p^"th"$ node in the $q^"th"$ layer
- $delta_p^q$ is the error value of the $p^"th"$ node in the $q^"th"$ layer
