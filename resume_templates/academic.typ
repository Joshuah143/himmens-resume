#import "utils.typ"
#let show_amounts = false

// Academic resume template (language-agnostic)
#let academic_template(content) = {
  let uservars = (
      headingfont: "New Computer Modern",
      bodyfont: "New Computer Modern",
      fontsize: 10pt,
      linespacing: 6pt,
      sectionspacing: 0pt,
      showAddress: true,
      showNumber: true,
      showTitle: true,
      headingsmallcaps: true,
      breakable: false,
  )

  // Get UI text from content file
  let ui = content.ui
  
  set page(
      paper: "us-letter",
      margin: 1.25cm,
      footer: context [
          #set text(size: 8pt)
          #grid(
              columns: (1fr, 1fr),
              align(left)[#ui.labels.updated: #datetime.today().display("[year]-[month]-[day]")],
              align(right)[#ui.labels.page #counter(page).display(
                "1/1", both: true,
              )]
          )
      ],
  )

  set text(
      font: uservars.bodyfont,
      size: uservars.fontsize,
      hyphenate: false,
  )

  set list(
      spacing: uservars.linespacing
  )

  set par(
      leading: uservars.linespacing,
      justify: true,
  )

  show heading.where(
      level: 2,
  ): it => block(width: 100%)[
      #v(uservars.sectionspacing)
      #set align(left)
      #set text(font: uservars.headingfont, size: 1em, weight: "bold")
      #if (uservars.at("headingsmallcaps", default:false)) {
          smallcaps(it.body)
      } else {
          upper(it.body)
      }
      #v(-0.75em) #line(length: 100%, stroke: 1pt + black)
  ]

  show heading.where(
      level: 1,
  ): it => block(width: 100%)[
      #set text(font: uservars.headingfont, size: 1.5em, weight: "bold")
      #if (uservars.at("headingsmallcaps", default:false)) {
          smallcaps(it.body)
      } else {
          upper(it.body)
      }
      #v(2pt)
  ]

  // Headers
  align(center)[
      = #content.personal.name
      #block(width: 100%)[
          *#content.personal.titles.join("  /  ")*
          #v(-4pt)
      ]
      #block(width: 100%)[
          #set text(font: uservars.bodyfont, weight: "medium", size: uservars.fontsize)
          #pad(x: 0em)[
              #let profiles = (
                  box(link("mailto:" + content.personal.email)),
                  box(link("tel:" + content.personal.phone)),
                  box(link(content.personal.url)[#content.personal.url.split("//").at(1)])
              )
              
              #if "profiles" in content.personal {
                  for profile in content.personal.profiles {
                      profiles.push(
                          box(link(profile.url)[#profile.url.split("//").at(1)])
                      )
                  }
              }
              
              #profiles.join([#sym.space.thin #sym.diamond.filled #sym.space.thin])
          ]
      ]
  ]

  // Education
  [== #ui.sections.education]
  
  [
    *#content.education.institution* #h(1fr) *#content.education.location* \
    #text(style: "italic")[#content.education.studyType] #ui.labels.in #content.education.area #h(1fr) #utils.strpdate(content.education.startDate) #sym.dash.en #utils.strpdate(content.education.endDate) \
  ]
  
  if "highlights" in content.education {
      for highlight in content.education.highlights [
          - #highlight \
      ]
  }

  // Work Experience
  [== #ui.sections.work]
  
  for w in content.work {
      if w.show != true { continue }
        
      [
        *#w.organization* #h(1fr) *#w.location* #linebreak()
      ]
          
      // Create a block layout for each work entry
      let index = 0
      for p in w.positions {
          if p.show != true { continue }
          if index != 0 { v(0.6em) }
              
          [
              // Line 2: Position and Date Range
              #text(style: "italic")[#p.position] #h(1fr) #utils.strpdate(p.startDate) #sym.dash.en #if p.endDate == "present" { ui.labels.present } else { utils.strpdate(p.endDate) }
          ]
              
          // Highlights or Description
          for hi in p.highlights [
              - #eval(hi, mode: "markup")
          ]
              
          index = index + 1
      }
  }

  // Publications and Presentations
  if "publications" in content {
    [== #ui.sections.publications]
    
    for pub in content.publications {
      if pub.visible != false [
        #text(weight: "bold")[#pub.name] #ui.labels.at #pub.publisher #h(1fr) #utils.strpdate(pub.releaseDate) \
      ]
      
      if "highlights" in pub and pub.highlights != none {
        for highlight in pub.highlights [
          - #highlight \
        ]
      }
    }
  }

  // Awards
  if "awards" in content {
    [== #ui.sections.awards]
    
    for award in content.awards {
      if award.visible {
        // Parse ISO date strings into datetime objects
        let date = utils.strpdate(award.date)
        
        [
          // Line 1: Award Title and Value
          #if ("value" in award and award.value != none) and show_amounts [
              *#award.title* (\$#award.value) #linebreak()] else [
              *#award.title* #linebreak()
          ]
          // Line 2: Issuer and Date
          #ui.labels.issued_by #text(style: "italic")[#award.issuer] #h(1fr) #date \
        ]
        
        // Summary or Description
        if "highlights" in award and award.highlights != none {
          for hi in award.highlights [
              - #eval(hi, mode: "markup")
          ]
        }
      }
    }
  }

  // Leadership and Activities
  if "advocacy" in content {
    [== #ui.sections.advocacy]
    
    for role in content.advocacy {
      if role.visible != false [
        #text(weight: "bold")[#role.position] #linebreak()
        #role.organization #h(1fr) #role.location \
        #utils.strpdate(role.startDate) #sym.dash.en #if role.endDate == "present" { ui.labels.present } else { utils.strpdate(role.endDate) } \
      ]
      
      for highlight in role.highlights [
        - #eval(highlight, mode: "markup") \
      ]
    }
  }

  // Skills
  [== #ui.sections.skills]
  
  for skill in content.skills {
    if skill.visible [
      - *#skill.title*: #skill.description
    ]
  }

  // Experiences
  if "experiences" in content {
    [== #ui.sections.experiences]
    
    for exp in content.experiences {
      if exp.visible [
        - *#exp.name* (#exp.organization): #exp.description
      ]
    }
  }
}