#let project(title: "", authors: (), body) = {
  // Set the document's basic properties.
  set document(author: authors.map(a => a.name), title: title)
  set text(lang: "zh", font: ("linux libertine", "SimSun"))
  set heading(numbering: "1.1.1")
  set par(leading: 0.55em, first-line-indent: 1.8em, justify: true)
  set page(numbering: "1", number-align: center, margin: 1.2in)
  set math.equation(numbering: "(1)")

  show strong: text.with(font: ("linux libertine", "SimHei"))
  show emph: text.with(font: ("linux libertine", "STKaiti"))
  show par: set block(spacing: 0.55em)

  show heading: it => context [
    #if it.level == 1 and counter(page).get().at(0) != 1 {
      pagebreak(weak: true)
    }
    #strong(it)
    #if it.outlined {
      par[#text(size:0.0em)[#h(0.0em)]]
    }
  ]
  show heading: set block(above: 1.4em, below: 1em)
  show figure: set block(breakable: true)

  // Title row.
  align(center)[
    #block(text(weight: 700, 1.75em, title))
  ]

  // Author information.
  pad(
    top: 0.5em,
    bottom: 0.5em,
    x: 2em,
    grid(
      columns: (1fr,) * calc.min(3, authors.len()),
      gutter: 1em,
      ..authors.map(author => align(center)[
        *#author.name* \
        #author.email \
        #author.affiliation
      ]),
    ),
  )

  body
}
