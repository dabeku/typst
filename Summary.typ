// Summary

#heading(numbering: none, outlined: false)[Summary]

Within the scope of the underlying diploma thesis the feasibility and implementation of a traditional wireless intrusion detection system (WIDS), combined with an artificial neural network (ANN), is shown.

After explaining the theoretical background, several tools which are used for network infiltration, WEP key cracking and intrusion detection are evaluated. Finally, design details of the WIDS and possible improvements are illustrated.

The WIDS consists of four parts:

The first component, the _data gatherer_, is used to collect data either from a file or directly from the network. The second one, the _data processor_, contains the ANN which is responsible for learning how an attack works and a preprocessor which is needed to prepare the WIDS for learning. The third component, the _data storage_, saves the configuration of the neural network after performing the initial training phase. The last component, the _response component_, alerts the network operator about ongoing threats.

The configuration and evaluation of the WIDS starts with finding the best properties for the neural network by using the trial-and-error method. Afterwards, the WIDS is trained and tested. The test is done by using previously captured network traffic files which include different attacks.

The obtained results show that using a neural network in an IDS offers several promising potentials. It is now possible to react to changes in the network characteristics such as the average number of connected clients in a certain period of time. The WIDS detects all attacks presented in the tests.
