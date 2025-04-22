#import "utils.typ"

// Business resume template (language-agnostic)
#let business_template(content) = {
  let uservars = (
      headingfont: "New Computer Modern",
      bodyfont: "New Computer Modern",
      fontsize: 10pt,
      linespacing: 6pt,
      sectionspacing: 0pt,
      showAddress: true,
      showNumber: true,
      showTitle: true,
      headingsmallcaps: false,
      breakable: false,
  )

  // Get UI text from content file
  let ui = content.ui

  set page(
      paper: "us-letter",
      margin: 1.25cm,
      footer: [
          #set text(size: 8pt)
          #grid(
              columns: (1fr, 1fr),
              align(left)[#ui.labels.updated: #datetime.today().display("[year]-[month]-[day]")],
              align(right)[#ui.labels.page 1/1]
          )
      ],
  )

  set text(
      font: uservars.bodyfont,
      size: uservars.fontsize,
      hyphenate: false,
  )

  let ubcblue = rgb("#002145")
  show link: underline

  show text.where(weight: "bold"): set text(fill: ubcblue)
  show text.where(weight: "regular"): set text(fill: rgb("#333333"))
  set grid.cell(align: top + left)

  show heading: it => [
    #text(fill: ubcblue)[#it.body] #box(width: 1fr, line(length: 100%, stroke: ubcblue + 0.5pt))
  ]

  // Job function definition
  let job = (title: "", 
            company: "", 
            description: "",
            date: "", 
            actions: [],
            site: "",
            visible: true) => {
    if (visible) [ 
      #text(weight: "bold")[#title] \
      #company | #date 
      #if site != "" [
        | #site 
      ]\ 
      #if description != "" [
        #description \
      ]
      #for action in actions [
        - #action \
      ]
    ]
  }

  // Split job function definition
  let split_job = (title: "", 
            company: "", 
            description: "",
            date: "", 
            actions: [],
            site: "",
            visible: true) => {
    if (visible) {
      grid(columns: (1.7fr, 3fr), column-gutter: 10pt, row-gutter: 0pt,
        [ #text(weight: "bold")[#title] \
        #company \
        #date \ 
        #if site != "" [
        #link(site) \
      ] ],
        [#if description != "" [
        #description \
      ]
        #for action in actions [
          - #action \
        ]]
      )
    }
  }

  // Award function definition
  let award = (title: "", 
             organization: "", 
             date: "", 
             description: [],
             visible: true) => {
    if (visible) [
      #text(weight:"bold")[#title] | #date \
      #for d in description [
        #d \
      ]
    ]
  }

  // Skill function definition
  let skill = (title: "", 
             description: "",
             visible: true) => {
    if (visible) [
      #text(weight:"bold")[#title] | #description \
    ]
  }

  // Achievement function definition
  let achievement = (focus: "", 
                    description: "",
                    visible: true) => {
    if (visible) [
      - #text(weight:"bold")[#focus] #description \
    ]
  }

  // Begin actual resume
  align(center)[
    #text(size: 17pt, font: "New Computer Modern", weight: "bold")[#content.personal.name] \
    #link("mailto:" + content.personal.email)[#content.personal.email] | #content.personal.phone | #link(content.personal.url)[#content.personal.url.split("//").at(1)] \
    #text(weight: "bold")[#content.personal.titles.at(0)] #ui.labels.at #ui.labels.university \
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
          #text(weight: "bold")[#position.position]
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

  if "publications" in content {
    for pub in content.publications {
      if pub.visible != false [
        #text(weight: "bold")[#pub.name] #ui.labels.at #pub.publisher #h(1fr) #utils.strpdate(pub.releaseDate) \
        #if "highlights" in pub and pub.highlights != none {
          for highlight in pub.highlights [
            - #highlight \
          ]
        }
      ]
    }
  }

  // Awards section
  [= #ui.sections.awards]

  if "awards" in content {
    for award_item in content.awards {
      if award_item.visible [
        #text(weight: "bold")[#award_item.title]
        | #utils.strpdate(award_item.date) \
        #for highlight in award_item.highlights [
          #highlight \
        ]
      ]
    }
  }

  // Advocacy section
  [= #ui.sections.advocacy]

  if "advocacy" in content {
    for role in content.advocacy {
      if role.visible != false [
        split_job(
          title: role.position,
          company: role.organization,
          date: utils.strpdate(role.startDate) + " - " + (if role.endDate == "present" { ui.labels.present } else { utils.strpdate(role.endDate) }),
          actions: role.highlights,
          visible: true
        )
      ]
    }
  } else {
    split_job(
      title: "Highly Qualified Personnel (HQP) Advisory Committee Member",
      company: "Arthur B McDonald Astroparticle Physics Institute",
      date: "2024 - Present",
      actions: (
        "Worked with members across Canada to develop opportunity lists for students and recent graduates.", 
        "Shared McDonald Institute opportunities with eligible HQP in BC and Alberta."),
      visible: true
    )

    split_job(
      title: "Advisory Team Member",
      company: "Child Rights Connect",
      date: "2021 - 2023",
      actions: (
        "Provided guidance to UN delegations on communication strategies for high-level rights goals.", 
        "Presented to governments and consulted on international initiatives to support the UN Convention on the Rights of the Child."),
      visible: true
    )
  }

  // Experiences section
  [= #ui.sections.experiences]

  if "experiences" in content {
    for exp in content.experiences {
      if exp.visible [
        achievement(
          focus: "\"" + exp.name + "\"",
          description: exp.description,
          visible: true
        )
      ]
    }
  }
}