// Main file of the thesis
// Infiltrating Wireless Networks and Intrusion Detection
// A Hybrid Approach using Neural Networks

#set document(
  title: "Infiltrating wireless networks and intrusion detection - A hybrid approach using neural networks",
  author: "Daniel Kuster",
  date: datetime(year: 2006, month: 1, day: 1),
)

#set page(paper: "a4", margin: auto)
#set text(size: 11pt, lang: "en")
#set par(justify: true, leading: 0.9em, first-line-indent: 0em, spacing: 11pt)
#set heading(numbering: "1.1")

#let chapter-header = context {
  let elems = query(heading.where(level: 1).before(here()))
  if elems != () [
    #align(right)[#[_#(elems.last().body)_]]
  ]
}

// ---- Cover page (no page number) ----

#include "Cover.typ"

// ---- Front matter: roman page numbers, unnumbered chapters ----

#set page(
  numbering: "i",
  header: none,
  footer: context [#align(center)[#counter(page).display()]],
)
#counter(page).update(1)
#set heading(numbering: none)

#include "EidesstattlicheErklaerung.typ"
#pagebreak()

#include "Danksagung.typ"
#pagebreak()

#include "Zusammenfassung.typ"
#pagebreak()

#include "Summary.typ"
#pagebreak()

#outline(title: "Contents", indent: auto)

// ---- Main matter: arabic page numbers, numbered chapters ----

#set page(
  numbering: "1",
  header: chapter-header,
  footer: context [#align(center)[#counter(page).display()]],
)
#counter(page).update(1)
#set heading(numbering: "1.1")
#counter(heading).update(0)

#include "Fundamentals.typ"
#include "Analysis.typ"
#include "Implementation.typ"

// ---- Appendix (continues chapter numbering, as in the original) ----

#include "Appendix.typ"

// ---- Back matter: unnumbered ----

#set heading(numbering: none)

#pagebreak()
#outline(title: "List of Figures", target: figure.where(kind: image))

#pagebreak()
#outline(title: "List of Tables", target: figure.where(kind: table))

#pagebreak()
#include "Glossary.typ"

#pagebreak()
#bibliography("Bibliography.bib", title: "Bibliography", style: "apa")
