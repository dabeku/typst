// Zusammenfassung

#heading(numbering: none, outlined: false)[Zusammenfassung]

Diese Diplomarbeit zeigt die Machbarkeit und Implementierung eines Einbruchs-erkennungssystems für WLANs (WIDS), welches ein neurales Netzwerk (ANN) zur Erkennung von verschiedenen Attacken verwendet.

Nach der theoretischen Einführung in die Themen WLAN und neurale Netzwerke, werden einige, im Internet frei verfügbare Programme, die zum Mithören von Netzwerkpaketen, zum Brechen der WEP Verschlüsselung und zur Einbruchs-erkennung verwendet werden, vorgestellt. Im letzten Teil werden Details, des zu implementierenden WIDS, beschrieben und Verbesserungsvorschläge diskutiert.

Das WIDS besteht aus vier Teilen:

Die erste Komponente, genannt _data gatherer_, holt sich Netzwerkpakete entweder aus einer Datei oder direkt von der Netzwerkkarte. Die zweite Komponente, _data processor_, enthält das neurale Netzwerk, welches für das Lernen der Charakteristika von verschiedenen Attacken verantwortlich ist und einen Präprozessor, der sich um die Initialisierung des WIDS kümmert. Der dritte Teil, _data storage_, kümmert sich um die Speicherung der Eigenschaften des neuralen Netzwerks. Der vierte Teil, _data response_, informiert den Netzwerkadministrator über stattfindende Attacken.

Die Evaluierung des WIDS beginnt mit der Suche nach den besten Parametern für das eingesetzte neurale Netzwerk. Anschließend wird das WIDS mit Hilfe von Dateien, die mitgeschnittene Netzwerkpakete enthalten, getestet.

Die resultierenden Ergebnisse zeigen, dass der Einsatz eines neuralen Netzwerks einiges an Potential bietet. Es ist nun möglich, auf Veränderungen der Netzwerkcharakteristika, wie zum Beispiel der durchschnittlichen Anzahl der angemeldeten Benutzer in einem WLAN, zu reagieren. Das WIDS erkennt alle Angriffe, die im Laufe der Tests angewendet wurden.
