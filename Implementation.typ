= Development of a WIDS

== Overview

As described in @l-sec:wids_definition the purpose of a wireless intrusion detection system is to detect a malicious client in a network. This chapter shows a concept of a hybrid WIDS which is capable of identifying different threats in a WLAN. Appendix @l-sec:implementation shows the tools which are used to create the WIDS and the test environment.

Possible threats include rogue APs, unknown clients, association and disassociation flood attacks. First, the goals of the WIDS are discussed. Then, design details like the classification of the traffic in a network and the process of feature selection is shown. Additionally, an algorithm which finds the best feature set for every problem that needs to be solved is described.

== Goals

The goal of the tool being developed is to create a hybrid WIDS which on the one hand uses well known techniques to detect threats like rogue APs and malicious users. On the other hand it uses a neural network to learn how to identify different wireless threats like association and disassociation floods. The following list shows the main goals of the tool:

- It should be possible to use it in every WLAN without worrying about the type of encryption used
- Use a neural network to detect association and disassociation flood attacks after a learning phase
- The system should be able to react to changes in the characteristics of the network. That means in other words that the WIDS realises when the properties, like the average amount of traffic or the number of connected clients in a network, change
- Use white lists to detect rogue APs and malicious clients
- It has to be able to receive the input values either from a pcap file#footnote[See glossary] or directly from a capturing NIC. The idea is to perform learning by using a previously stored pcap file. After the learning phase is finished the WIDS starts to capture and analyse packets for intrusion detection

== Design

The following sections explain design details of the WIDS, its preprocessor and the process of finding the best feature set for the neural network.

=== WIDS <l-sec:design_wids>

The overall design of the WIDS follows the suggested structure presented in @l-sec:ids_structure. @l-wids_dataflow shows the four components used and the data flow in the WIDS.

#figure(
  image("graphics/WIDS_structure.png", width: 70%),
  caption: [Components and data flow in the WIDS],
) <l-wids_dataflow>

*_Data Gathering_*

This component is used to receive data either from a previously stored file or directly from a capturing NIC. The data gathering component forwards the data directly to the data processor.



*_Data Processing_*

The core of the data processing component is a neural network. After training it is capable of identifying association and disassociation flood attacks. It uses the backpropagation learning algorithm described in @l-sec:backpropagation. In addition to the neural network the processor also identifies rogue APs and unknown clients by comparing the content of the white lists created by a preprocessor (described in @l-sec:preprocessing) with the packets received from the data gathering component.

*_Data Storage_*

After the training phase this component stores information about a trained neural network. Stored information includes all weights of the network and the _scaling values_#footnote[A scaling value specifies the maximum amount of packets with a certain type/subtype that occur in a two second time slot] received. That makes it possible to

- create a trained neural network by assigning the stored weight values to the connections between neurons. As a consequence no training phase needs to be done
- perform the training phase in several steps. After one training phase is finished it is possible to continue training the network with additional data. This is an important point for the WIDS to be able to react to changes in the network behaviour. The training of the neural network can continue after the initial learning phase is finished by using the data coming directly from the capturing NIC

*_Response_*

This component is responsible for informing the operator of a WLAN about ongoing threats in the network. The WIDS prints an alert message on the screen.

=== Preprocessing <l-sec:preprocessing>

Before the WIDS can be trained several preprocessing steps need to be performed. In order to be able to perform these steps the preprocessor requires a pcap file with normal traffic and one or more files which contain flood specific traffic.

The preprocessor creates white lists for rogue AP and malicious user detection. These lists store the BSSID of every network and the MAC address of every client found inside the normal traffic file.

It addition to the white lists the preprocessor creates additional pcap files (named _relevant files_) which are used by the neural network in order to learn the characteristics of different flood attacks. A prototype implementation of the WIDS, which used only the normal traffic file and the flood files to learn, showed, that the neural network does not succeed in learning the characteristics of a flood attack. The reason for that is that association and disassociation packets occur very rarely compared to other packets. As a consequence the neural network would learn too slowly. The relevant files are created out of the normal traffic files and contain only those data packets with the type and subtype field that also occur in the respective flood file.

As soon as these preprocessing steps are finished the network can be trained. The training requires a pcap file with normal traffic, all relevant files and all files which contain flood specific traffic.

=== Features

"Since the ability to identify the important inputs and redundant inputs of a classifier results in reduced problem size, faster training and possibly more accurate results, it is critical to be able to identify the important features of network traffic data for intrusion detection in order for the IDS to achieve maximal performance" @nn_features. That means in other words that the quality of the neural network does not solely depend on the number of hidden layers or neurons used but also on the input features#footnote[A feature is for example the amount of traffic sent to a client or the number of connections coming from the same host in a specified period of time] chosen.

==== Feature Selection <l-sec:features>

The group of features used as inputs for the neural network is divided into two different sections:

/ Time irrelevant features: This type of features includes all values that are available by dissecting one single frame. These features do not consider the time aspect. All values are converted to binary values and then given to the neural network.

  - Type field
  - Subtype field
  - Retry field

/ Time based features: This type of features takes the period of time that passed since a specific event that happened in the past into account. The WIDS uses two features of this type:

  - The number of frames with a certain type and subtype in the past two seconds. This feature is needed to detect association and disassociation floods. The higher this number is the more probable it is that an attack occurs. When given to the neural network this value is scaled from $0$ to $1$ by using the scaling value as divisor. In case the resulting value is bigger than $1$ it is set to $1$. This formula is written as

    $ ("number of same packets in the past two seconds") / ("scaling value of that packet type") $

  - The number of disassociations of legitimate clients in the past two seconds. This feature is needed due to the fact that a disassociation flood is harmless in case the source address of the packet is never used in the network. For that reason this feature is needed which checks for packets with a source address of legitimate clients. Again, when given to the neural network this value is also scaled from $0$ to $1$ by using the maximum number of legitimate clients as divisor. This formula is written as

    $ ("number of disassociations in the past two seconds") / ("maximum number of legitimate clients") $

==== Performance Based Ranking Method

The following algorithm describes a technique to find the best feature set for a specific problem. It was taken and adopted from @nn_features. Depending on the results obtained this algorithm classifies a feature either as _important_, _secondary_ or _unimportant_.

#align(center)[
  #box(stroke: 1pt, inset: 1em, width: 250pt)[
    + Create the training and testing set
    + Remove one feature of the neural network
    + Train the neural network using the training set
    + Calculate the accuracy using the testing set
    + Rank the importance of the removed feature according to the rules shown below
  ]
]

The following list shows the rules which rank the importance of one particular feature:

- If $a$ decreases and $r$ increases and $e$ decreases: $f$ is important
- If $a$ decreases and $r$ increases and $e$ increases: $f$ is important
- If $a$ decreases and $r$ decreases and $e$ increases: $f$ is important
- If $a$ unchanges and $r$ increases and $e$ increases: $f$ is important
- If $a$ unchanges and $r$ decreases and $e$ increases: $f$ is secondary
- If $a$ unchanges and $r$ increases and $e$ decreases: $f$ is secondary
- If $a$ unchanges and $r$ decreases and $e$ decreases: $f$ is unimportant
- If $a$ increases and $r$ increases and $e$ decreases: $f$ is secondary
- If $a$ increases and $r$ decreases and $e$ increases: $f$ is secondary
- If $a$ increases and $r$ decreases and $e$ decreases: $f$ is unimportant

where

- $a$ is the accuracy of the result
- $r$ stands for the training time
- $e$ stands for the testing time
- $f$ is the feature that was removed before training

==== Neural Network

In addition to the input features there exist other properties which can improve the performance of the WIDS. The network based features describe the structure and properties of the neural network itself. All features presented in this set can be modified for every type of problem. @l-sec:test_nn shows the process of finding the best values for each of these features.

- Initial weight values
- Number of hidden layers
- Number of neurons in each hidden layer
- Learning rate
- Appearance of the sigmoid function

=== Classification

Normal traffic in a wireless network has specific properties like the average number of connections to an AP or the amount of traffic sent over the network. Whenever a cracker launches an attack on a network these properties change. As an example a network could have 50 connected clients. When a malicious user would start a disassociation flood attack he would send a large amount of packets of the same type in a short period of time. In a network with legitimate users this would generally not happen.

The traffic in a wireless network is classified into three different groups. These groups are needed so that the WIDS can tell what kind of attack is currently threatening the network.

/ Normal traffic: This type identifies normal traffic without the occurrence of any attack
/ Association flood: This type identifies an association flood. This traffic is characterised by a large amount of association frames in a short period of time
/ Disassociation flood: This type identifies a disassociation flood. This traffic is characterised by a large amount of disassociation frames coming from legitimate clients in a short period of time

= Tests and Results

== Introduction

This chapter explains the results obtained by the WIDS. At the beginning, the configuration parameters for the neural network which is used in the WIDS are figured out. Afterwards, the WIDS is trained and tested by using different pcap files. Finally, the results are discussed and possible improvements are shown.

== Neural Network <l-sec:test_nn>

/ Initial weight values: These values are especially important whenever a neural network is used which is trained by using a small amount of training data or training cycles. @l-error_weights displays the error rates of three training cycles performed one after another. The network configuration stays the same for all three tests except that the weight values change since they are initialised randomly.

  #figure(
    image("graphics/Error_time.png", width: 70%),
    caption: [A comparison using different initial weight values],
  ) <l-error_weights>

  The result is that all calculated error rates differ in the first 100 training cycles. As it turns out after a training phase that is long enough all error rates conform the each other.



/ Number of hidden layers: One feature that affects the time needed to train the neural network is the number of hidden layers. In this test the number of neurons in each hidden layer is set to the number of input nodes. Tests show that an increasing number of hidden layers raises the time needed to train the network but does not increase the quality of the resulting network.

  Each test is performed with 10.000 training cycles. The result is shown in @l-train_layers and @l-error_hidden. In addition to the amount of time needed, the number of training cycles to train the network also increases.

  #figure(
    table(
      columns: (auto, auto, auto),
      table.header([*Hidden layers*], [*Time needed*], [*Error rate*]),
      [1], [5.658 sec], [$1.23151 * 10^(-8)$],
      [2], [10.756 sec], [$2.13083 * 10^(-8)$],
      [3], [15.602 sec], [$1.65828 * 10^(-8)$],
      [4], [20.459 sec], [$3.89512 * 10^(-8)$],
    ),
    caption: [Resulting time and error when using 1, 2, 3 and 4 hidden layers],
  ) <l-train_layers>

  #figure(
    image("graphics/Error_hidden_layers.png", width: 70%),
    caption: [A comparison using 1, 2, 3 and 4 hidden layers],
  ) <l-error_hidden>

  Since the resulting error rate is not affected and the time needed to train the network increases with every additional layer the WIDS uses one hidden layer.


/ Number of neurons in the hidden layers: @l-train_neurons shows that choosing a higher number of neurons in a hidden layer can improve the resulting output of the network. On the other hand each additional neuron increases the time needed. Each test is performed with 10.000 training cycles.

  #figure(
    table(
      columns: (auto, auto, auto),
      table.header([*Neurons*], [*Time needed*], [*Error rate*]),
      [9], [5.779 sec], [$2.09958 * 10^(-8)$],
      [18], [9.263 sec], [$3.2259 * 10^(-9)$],
      [36], [15.953 sec], [$2.23715 * 10^(-9)$],
      [72], [30.634 sec], [$7.80079 * 10^(-10)$],
    ),
    caption: [Time needed to train the network using 9, 18, 36 and 72 neurons],
  ) <l-train_neurons>

  Another test shows that it takes 30 seconds to test the neural network with 50000 packets and 18 hidden neurons. Therefore the WIDS can process 1666 packets per second. Assuming a 16 MBit WLAN and an average packet size of 1500 bytes it would be necessary to process 1333 packets per second in case the network operates at full capacity. That shows that the WIDS is fast enough to be used in a 16 MBit WLAN.

  Due to the amount of time needed to train the network and the resulting performance of the test the WIDS uses 18 neurons in the hidden layer.

/ Learning rate: @nn_learning_rate states that "the larger the learning rate ... the larger the weight changes on each epoch, and the quicker the network learns. However, the size of the learning rate can also influence whether the network achieves a stable solution. If the learning rate gets too large, then the weight changes no longer approximate a gradient descent procedure". That means in other words that choosing a good learning rate results in better network performance than just setting it to a high value near $1$.

  @l-error_learning_rates shows the first 250 training cycles of the WIDS using different learning rates.

  #figure(
    image("graphics/Error_learning_rates.png", width: 70%),
    caption: [A comparison using 0.2, 0.3, 0.4 and 0.5 as learning rate],
  ) <l-error_learning_rates>

  On the basis of these results and the warning not to choose a value that is too high the learning rate of the WIDS is set to $0.5$.

/ Appearance of the sigmoid function: As shown in @l-error_sigmoid the value for $a$ in the formula shown in @l-sec:activation provides continuity for the learning process. The result of this test shows that the lower the value $a$ the smaller the difference between two steps in time is. In addition to that, the time needed to train a network increases.

  #figure(
    image("graphics/Error_sigmoid.png", width: 70%),
    caption: [A comparison using 0.25, 0.5, 1 and 2 for the sigmoid function],
  ) <l-error_sigmoid>

  Since one single packet should not affect the obtained result too much and in order to avoid a learning process which takes a lot of time the WIDS uses the value of $1$ for $a$.

== WIDS <l-sec:results_wids>

The following section shows the results obtained by the WIDS. It uses a neural network with the configuration parameters shown in the previous section.

=== Training

The WIDS is trained by using previously stored pcap files. The characteristics of these files are shown in @l-train_env.

The file in the _Normal traffic_ column specifies the capture in which no attack occurs. It is a capture of the traffic in a WLAN which is WPA protected. It is created by using a WLAN NIC which is put into monitor mode and the tool Ethereal#footnote[Ethereal is a freely available packet capturing tool. It can be downloaded from http://www.ethereal.com/].

#figure(
  table(
    columns: (auto, 60pt, 60pt, 75pt),
    table.header([], [*Normal traffic*], [*Association flood*], [*Disassociation flood*]),
    [Size], [9738 KB], [21 KB], [20 KB],
    [Time period], [57 sec], [9 sec], [9 sec],
    [Packet count], [50000], [500], [500],
    [Associations], [5], [500], [0],
    [Disassociations], [4], [0], [500],
    [Rogue APs], [0], [0], [0],
    [Unknown clients], [0], [500], [0],
    [Association flood], [no], [yes], [no],
    [Disassociation flood], [no], [no], [yes],
  ),
  caption: [Properties of the files used for training the WIDS],
) <l-train_env>

The flood files specified in the _Association flood_ and _Disassociation flood_ column are created by using a self-made tool#footnote[This tool is named _DumpCreator_ and is available on the shipped CD]. Both files consist of packets which are used for the respective flood attack only. The association flood uses random source addresses whereas the disassociation flood contains only those MACs as source which are also available in the respective WLAN where the WIDS is used.

=== Testing

After the training phase is finished the WIDS is tested. @l-result_train shows the average error values obtained when testing the network with the files used for training shown in @l-train_env.

#figure(
  table(
    columns: (auto, 60pt, 60pt, 75pt),
    table.header([], [*Normal traffic*], [*Association flood*], [*Disassociation flood*]),
    [No attack], [0.999285], [0.0158409], [0.00934418],
    [Association flood], [0.000839386], [0.981713], [0.00531103],
    [Disassociation flood], [0.00019222], [0.00483618], [0.988265],
    [Rogue APs], [0], [0], [0],
    [Unknown clients], [0], [500], [0],
  ),
  caption: [Average resulting error values using the training files],
) <l-result_train>

The WIDS identifies normal traffic with almost a 100% certainty. The different flood attacks are identified with a guarantee of 98%. Additionally, it detects 500 unknown clients when testing the association flood file since the client's source addresses were created randomly in this file.

The next test is performed with pcap files with the characteristics shown in @l-test_env.

#figure(
  table(
    columns: (auto, auto, auto, auto, auto),
    table.header([], [*Test 1*], [*Test 2*], [*Test 3*], [*Test 4*]),
    [Size], [9898 KB], [10797 KB], [10797 KB], [10795 KB],
    [Time period], [65 sec], [45 sec], [45 sec], [45 sec],
    [Packet count], [50000], [50150], [50150], [50100],
    [Associations], [2], [153], [3], [53],
    [Disassociations], [2], [2], [152], [52],
    [Rogue APs], [0], [0], [2], [3],
    [Unknown clients], [0], [149], [0], [49],
    [Association flood], [no], [yes], [no], [yes],
    [Disassociation flood], [no], [no], [yes], [yes],
  ),
  caption: [Properties of the files used for testing the WIDS],
) <l-test_env>

The first test file is a capture of the WLAN with similar properties like the file used for training.

The second file is another capture of the WLAN but it also includes MACs of unknown clients and an association flood attack. The flood is performed using 149 association requests of clients with a randomised MAC address.

The third file includes two rogue APs and a disassociation flood. The flood is done by using 150 disassociation requests of legitimate clients.

The last test file contains all types of attacks. It uses 49 association requests and 50 disassociations of legitimate clients. Additionally, it contains 3 rogue APs and 49 unknown MAC addresses.

@l-result_test shows the results obtained when testing the WIDS using the files shown in @l-test_env. The values in the rows named _Association floods_ and _Disassociation floods_ specify the number of feature sets#footnote[One feature set consists of all features described in @l-sec:features and is created for every single packet received.] recognised that identify a specific attack. That means in other words that $0$ indicates that no attack occurs. All values above $0$ mean that one or more feature sets are found which characterise a certain flood attack.

#figure(
  table(
    columns: (auto, auto, auto, auto, auto),
    table.header([], [*Test 1*], [*Test 2*], [*Test 3*], [*Test 4*]),
    [Rogue APs], [0], [0], [2], [3],
    [Unknown clients], [0], [149], [0], [49],
    [Association floods], [0], [148], [0], [48],
    [Disassociation floods], [0], [0], [148], [48],
  ),
  caption: [The resulting numbers of attacks found in the test files],
) <l-result_test>

The test result of the first test file shows the desired result. No malicious activity is found.

In the second test file the WIDS finds the correct number of unknown clients and also detects an association flood. An interesting thing about this result is that the number of feature sets found that identify a flood attack is 148 and not 149. The reason is that the first packet of the flood attack is considered as normal traffic since the number of association packets in the past two seconds is still $0$. This shows that the WIDS alerts a flood attack in case the number of association packets received in a two second time slot exceeds $1$.

The results of the third test files show that the WIDS detects a disassociation flood attack in case the number of disassociations of legitimate clients in the past two seconds exceeds the value $2$. Again, the reason is that the first two disassociations of the attack are considered as valid. In addition to the flood attack both rogue APs are detected correctly.

The result of the fourth test file shows that the WIDS detects all attacks that occur in the network.

= Conclusion

== Neural Networks for Intrusion Detection

The results shown in @l-sec:results_wids indicate that a neural network can be used efficiently in an intrusion detection system. A big advantage of using a neural network lies in the fact that the IDS can react to changes in the network characteristics.

Another important aspect is the preciseness of the system. If the characteristics in a WLAN do not change over time and the attacks are performed with enough packets the IDS detects all occurring association and disassociation flood attacks as well as malicious clients and rogue APs.

On the other hand there exist some drawbacks that an IDS developer needs to think of: Due to the complex structure of the neural network it is necessary to provide enough memory and computing power. Especially the training phase takes a lot of time depending on the amount of available data. Additionally, the network links between the data gatherer(s) and the data processor need to be faster than the speed in the WLAN network itself.

== Neural Networks and Traditional Methods

@nn_vs_traditional poses the question whether it is better to use neural networks or traditional techniques#footnote[Traditional techniques in this context mean an anomaly based IDS which does not use a neural network. See @l-sec:sig_anom_ids for details] to solve certain problems. The answer is that this is "an unanswerable question" @nn_vs_traditional[p. 4]. The main problem lies in the characteristics of ANNs:

First, the weight values that are used to setup an uninitialised network are chosen randomly. This means the obtained results differ slightly each time the network is trained even if the same training set is used.

Next, as described in @l-sec:features, the success of learning something is highly dependent on the features chosen for the input nodes. As a consequence the quality of the results differs significantly if different features are chosen.

Finally, the architecture and properties of the neural network itself change the results obtained. @l-sec:test_nn shows that depending on the number of hidden layers and neurons the performance of the network varies.

== Future Work

The following section discusses tasks that need to be done before using the WIDS and possible improvements which make the WIDS more powerful.

=== Putting the WIDS into a Real Network

All tests have been done by using previously stored pcap files. The next step, to improve the WIDS, is to train it and put it in a WLAN to find out whether it behaves correctly and whether it reacts to changes in the network behaviour. This can only be done by running the WIDS over periods of several weeks and months.

Additionally, it is important to find out whether the neural network is fast enough to process the incoming traffic in real time or whether it is necessary to preprocess the traffic. In case the amount of traffic is too large for the neural network to handle it would be interesting to know how fast the WLAN may be until the WIDS can not process the data any longer.

=== Adding Remote Functionality

As described in @l-sec:design_wids the design of the WIDS makes it possible to create remote sensors which collect data in a WLAN and send it to the data processor. As a consequence the data gathering component needs to be realised as a stand alone tool which connects to the data processor: The data processor is the server which waits for incoming data packets. Currently the WIDS does not support this form of client/server architecture.

=== Adding Silent User Detection

If a malicious user is present in a network but not sending any packets, it is impossible for the WIDS to detect this client because it needs packets to work with. As a consequence it is necessary to extend the WIDS with the capability to send RTS packets. As described in @l-sec:hidden_node_problem the RTS/CTS handshake is used to overcome the hidden node problem. The answer to the RTS packet, the CTS frame, is sent automatically. This means that it is not possible (at least with unmodified hardware) to prevent the sending of a CTS packet. The RTS/CTS handshake makes it possible to detect clients although they do not send packets.

A drawback of this method is that a client needs to be known as malicious because it is necessary to know the MAC address to which the RTS packet is sent to.

=== Adding Scanner Fingerprinting

As described in @wlan_fingerprints some active wireless scanners like Netstumbler or Wellenreiter provide individual characteristics when they send frames. That makes it possible to find out what type of scanner an intruder is using.

=== Reacting on Intrusions

Currently the WIDS writes an alert message on the screen whenever a flood attack is recognised or an unknown MAC address is found. The next step is to react to possible threats automatically. Possible counter measures include modifying the firewall to block a certain client or to send a mail to the network administrator to inform about ongoing threats.

=== Providing a GUI

Currently the WIDS alerts the user by printing a message on the screen. It would be easier to configure and handle this tool if it is based on a GUI. It could consist of a configuration section which is capable of changing the structure of the neural network. Additionally, it should be possible to perform the training and testing phase of the WIDS graphically.

== Outlook

As explained in @IDS_terminology "Intrusion Detection Systems (IDS) are still in their infancy" and as a consequence used very rarely. On the other hand it is a very fast evolving area in computer science.

The underlying work shows that using a neural network can be advantageous and will very likely find its way in upcoming (wireless) intrusion detection systems.
