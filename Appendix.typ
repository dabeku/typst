= Backpropagation Example <l-sec:bp_walkthrough>

This section describes an example of training a backpropagation network by using the algorithm shown in @l-sec:backpropagation. The network uses the sigmoid shown in @l-sec:activation as activation function.

Similar examples can also be found in @backpropagation_example and @backpropagation_example_2.

== The Network Structure

The network that is used in this example is shown in @l-backpropagation_ex. It contains an input layer with two neurons, one hidden layer with two neurons and an output layer with two neurons. The initial weight values are already initialised with random values between -1 and 1. It uses a learning rate of 0.25 and no bias element is used.

#figure(
  image("graphics/Backpropagation_ex.png", width: 55%),
  caption: [An example of a backpropagation network],
) <l-backpropagation_ex>

== The Patterns to be Learnt

The goal of this example is to learn the patterns shown in @l-pattern_learn. The first output value $o_1$ indicates a flood attack with medium danger and the second value $o_2$ indicates a flood attack with high danger.

#figure(
  table(
    columns: (auto, auto, auto, auto),
    [$bold(x_1)$], [$bold(x_2)$], [$bold(o_1)$], [$bold(o_2)$],
    [1], [1], [0], [1],
    [1], [0], [1], [0],
    [0], [1], [1], [0],
    [0], [0], [0], [0],
  ),
  caption: [An example of a pattern set to be learnt],
) <l-pattern_learn>

== Step by Step Description

+ Calculate $c_p^L (i), p=1,...k_L$:

  Activate nodes in the hidden layer:

  Input of hidden neuron h1: $0.22*1 + 0.81*1 = 1.03$ \
  Input of hidden neuron h2: $0.37*1 + 0.59*1 = 0.96$ \
  Output of hidden neuron h1: $1 / (1+exp(-1.03)) = 0.736916$ \
  Output of hidden neuron h2: $1 / (1+exp(-0.96)) = 0.723122$

  Activate nodes in the output layer:

  Input of output neuron c1: $0.91*0.736916 + 0.35*0.7231218 = 0.923686$ \
  Input of output neuron c2: $0.70*0.736916 + 0.19*0.7231218 = 0.653234$ \
  Output of output neuron c1: $1 / (1+exp(-0.923686)) = bold(0.715793)$ \
  Output of output neuron c2: $1 / (1+exp(-0.653234)) = bold(0.657739)$

+ Calculate $delta_p^L, p=1,...,k_L$:

  Error value of output neuron c1: $(0.715793 - 0) * (0.715793) * (1 - 0.715793) = 0.145616$ \
  Error value of output neuron c2: $(0.657739 - 1) * (0.657739) * (1 - 0.657739) = -0.077049$

+ For $q = L - 1$ to $1$ calculate $delta_p^q, p=1,...,k_q$:

  Error value of hidden neuron h1: $[(0.145616 * 0.91) + (-0.077049 * 0.70)] * (0.736916) * (1 - 0.736916) = 0.015233$ \
  Error value of hidden neuron h2: $[(0.145616 * 0.35) + (-0.077049 * 0.19)] * (0.723122) * (1 - 0.723122) = 0.007273$

+ Update weight vectors:

  Update weight matrix 1:

  w(x1, h1): $0.22 - 0.25 * (0.015233 * 1) = 0.216192$ \
  w(x2, h1): $0.81 - 0.25 * (0.015233 * 1) = 0.806192$ \
  w(x1, h2): $0.37 - 0.25 * (0.007273 * 1) = 0.368182$ \
  w(x2, h2): $0.59 - 0.25 * (0.007273 * 1) = 0.588182$

  Update weight matrix 2:

  w(h1, c1): $0.91 - 0.25 * (0.145616 * 0.736916) = 0.883173$ \
  w(h2, c1): $0.35 - 0.25 * (0.145616 * 0.723122) = 0.323675$ \
  w(h1, c2): $0.70 - 0.25 * (-0.077049 * 0.736916) = 0.714195$ \
  w(h2, c2): $0.19 - 0.25 * (-0.077049 * 0.723122) = 0.203929$

+ Restart learning with next pattern.

= Aircrack versus WepLab <l-sec:aircrack_weplab>

This section shows a comparison between Aircrack (v2.41) and WepLab (v0.1.15). The following tables present how many seconds are needed to break a 64 bit WEP key. All tests are performed on an Intel Centrino laptop with 1600 Mhz and 512 MB RAM running Ubuntu Linux with the kernel version 2.6.12.

The sign "-" indicates that the tool did not find a correct solution and the "s" stands for stopped. This is used in case the test took more than five minutes.

== Aircrack

Aircrack was run by issuing: *aircrack -f _fudge factor_ -n 64 _file_*

@l-aircrack shows the test result of running aircrack. The numbers in the first line specify the fudge factor used.

#figure(
  table(
    columns: (auto, auto, auto, auto, auto, auto, auto),
    [*packets*], [*unique IVs*], [*2*], [*4*], [*8*], [*16*], [*32*],
    [100.000], [40.832], [-], [-], [01:01], [02:49], [02:48],
    [200.000], [82.465], [-], [-], [s], [s], [s],
    [300.000], [125.052], [-], [-], [s], [s], [s],
    [400.000], [167.740], [-], [-], [s], [s], [s],
    [500.000], [210.349], [-], [-], [s], [s], [s],
    [600.000], [253.787], [-], [-], [s], [s], [s],
    [700.000], [297.370], [-], [-], [s], [s], [s],
    [800.000], [340.960], [00:01], [00:01], [00:02], [00:02], [00:01],
    [900.000], [384.604], [00:02], [00:02], [00:01], [00:02], [00:01],
    [1.000.000], [428.195], [00:02], [00:02], [00:02], [00:02], [00:02],
  ),
  caption: [Aircrack test results],
) <l-aircrack>

== WepLab

WepLab was run by issuing: *weplab -r -k 64 --perc _value_ _file_*

@l-weplab shows the test result of running WepLab. The numbers in the first line specify the value used for the --perc parameter.

#figure(
  table(
    columns: (auto, auto, auto, auto, auto),
    [*packets*], [*unique IVs*], [*50*], [*70*], [*90*],
    [100.000], [40.832], [s], [s], [s],
    [200.000], [82.465], [-], [s], [s],
    [300.000], [125.052], [-], [s], [s],
    [400.000], [167.740], [-], [04:20], [s],
    [500.000], [210.349], [-], [-], [s],
    [600.000], [253.787], [-], [s], [s],
    [700.000], [297.370], [-], [-], [s],
    [800.000], [340.960], [00:05], [00:08], [00:57],
    [900.000], [384.604], [00:02], [00:02], [00:03],
    [1.000.000], [428.195], [-], [00:03], [00:03],
  ),
  caption: [WepLab test results],
) <l-weplab>

= Tools

Last visited on August 8th, 2006.

/ Aircrack:
  / Version: 2.41
  / URL: #link("http://www.aircrack-ng.org/doku.php")
  / OS: Linux, Windows

/ AirSnare:
  / Version: 1.5.0
  / URL: #link("http://home.comcast.net/~jay.deboer/airsnare/")
  / OS: Windows

/ AirSnort:
  / Version: 0.2.7
  / URL: #link("http://airsnort.shmoo.com/")
  / OS: Linux, Windows

/ Dwepcrack:
  / Version: 0.4
  / URL: #link("http://www.dachb0den.com/projects/dwepcrack.html")
  / OS: Linux

/ Kismet:
  / Version: 2005.08.R1
  / URL: #link("http://www.kismetwireless.net/")
  / OS: Linux

/ Netstumbler:
  / Version: 0.4.0
  / URL: #link("http://www.netstumbler.com/")
  / OS: Windows

/ WepLab:
  / Version: 0.1.5
  / URL: #link("http://weplab.sourceforge.net/")
  / OS: Linux, Windows

/ WIDZ:
  / Version: 1.5
  / URL: #link("http://www.loud-fat-bloke.co.uk/tools.html")
  / OS: Linux

/ Wireless Snort:
  / Version: 2.4.3
  / URL: #link("http://snort-wireless.org/")
  / OS: Linux, Windows

= Implementation <l-sec:implementation>

The implementation of this WIDS is a _proof of concept_ and shows whether it is possible to use a neural network for intrusion detection. Since it combines the use of white lists and a neural network it is titled as a _hybrid approach_.

The program was created in Eclipse#footnote[Eclipse is available at: #link("http://www.eclipse.org/")] using a gnu c++ compiler#footnote[MinGW is available at: #link("http://www.mingw.org/")] version 3.4.2 for Windows.

It was tested on an Intel Centrino laptop with 1600 Mhz and 512 MB RAM running under Windows XP Professional SP2.

The final version of the code has 4266 lines and can be found on the delivered CD.
