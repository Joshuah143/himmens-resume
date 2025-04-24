#import "utils.typ"

// Business resume template (language-agnostic)
#let business_template(content) = {
  // Get UI text from content file
  let ui = content.ui
  
  // Define colors
  let ubcblue = rgb("#002145")
  
  // Set font styling
  show link: underline
  set text(fallback: false)
  set text(font: "Open Sans", size: 11pt)
  show text.where(weight: "bold"): set text(fill: ubcblue)
  show text.where(weight: "regular"): set text(fill: rgb("#333333"))
  set grid.cell(align: top + left)
  
  // Set heading styling
  show heading: it => [
    #text(fill: ubcblue)[#it.body] #box(width: 1fr, line(length: 100%, stroke: ubcblue + 0.5pt))
    \
  ]

  // Set page layout
  set page(
    paper: "us-letter",
    margin: (x: 0.82in, y: 0.9in),
    footer: grid(columns: (50%, 50%), image("../assets/cooplogo.png"), grid.cell(align: right+horizon)[#text(font: "Open Sans", weight: "bold")[science.coop\@ubc.ca | 604-822-9677]])
  )
  
  // Begin actual resume
  align(center)[
    #text(size: 17pt, font: "Open Sans", weight: "bold")[#content.personal.name] \
    #link("mailto:" + content.personal.email)[#content.personal.email] | #content.personal.phone | #link(content.personal.url)[#content.personal.url.split("//").at(1)] \
    #text(weight: "bold")[#content.personal.titles.at(0)] #ui.labels.at #ui.labels.university \
    #text(weight: "bold")[#content.education.gpa] Average | #text(weight: "bold")[English], #text(weight: "bold")[French] (Working Knowledge) | #link("https://github.com/Joshuah143")[Github/Joshuah143]
  ]
  
  // Skills section
  [= #ui.sections.skills]
  
  for skill_item in content.skills {
    if skill_item.visible [
      #text(weight: "bold")[#skill_item.title] | #skill_item.description \
    ]
  }
  
  // Work experience section
  [= #ui.sections.work]
  
  for org in content.work {
    if org.show {
      for position in org.positions {
        if position.show [
          #text(weight: "bold")[#position.position] \
          #org.organization | #utils.strpdate(position.startDate) #sym.dash.en #if position.endDate == "present" { ui.labels.present } else { utils.strpdate(position.endDate) }
          #if org.url != "" [
            | #link(org.url)[#org.url.split("//").at(1)]
          ]\ 
          #for highlight in position.highlights [
            - #eval(highlight, mode: "markup") \
          ]
        ]
      }
    }
  }
  
  // Publications section
  [= #ui.sections.publications]
  
  // Publications and Presentations
  if "publications" in content {
    for pub in content.publications {
      if pub.visible != false [
        #text(weight: "bold")[#pub.name] \
        #pub.publisher #h(1fr) #utils.strpdate(pub.releaseDate) \
      ]
      
      if "highlights" in pub and pub.highlights != none {
        for highlight in pub.highlights [
          - #highlight \
        ]
      } else [

      ]
    }
  }
  
  // Awards section
  [= #ui.sections.awards]
  
  if "awards" in content {
    for award_item in content.awards {
      if award_item.visible [
        #text(weight: "bold")[#award_item.title] | #utils.strpdate(award_item.date) \
        #for highlight in award_item.highlights [#highlight] \
      ]
    }
  }
  
  // Advocacy section
  [= #ui.sections.advocacy]
  
  if "advocacy" in content {
    for role in content.advocacy {
      if role.visible != false {
        grid(columns: (1.7fr, 3fr), column-gutter: 10pt, row-gutter: 0pt,
          [ #text(weight: "bold")[#role.position] \
          #role.organization \
          #utils.strpdate(role.startDate) #sym.dash.en #if role.endDate == "present" { ui.labels.present } else { utils.strpdate(role.endDate) } \
          ],
          [
            #for highlight in role.highlights [
              - #highlight \
            ]
          ]
        )
      }
    }
  }
  
  // Experiences section
  [= #ui.sections.experiences]
  
  if "experiences" in content {
    for exp in content.experiences {
      if exp.visible [
        - #text(weight: "bold")["#exp.name"] #exp.description \
      ]
    }
  }
}