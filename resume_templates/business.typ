#import "utils.typ"

// Business resume template (language-agnostic)
#let business_template(content) = {
  let goc_mode = sys.inputs.at("goc", default: "false") == "true"
  let goc_labels = (
    full_time: "full-time",
    part_time: "part-time",
    hours_per_week: "hrs/week",
    pri: "PRI",
  )
  let format_employment = (pos) => {
    if "employment_type" not in pos { return "" }
    let label = if pos.employment_type == "part-time" { goc_labels.part_time } else { goc_labels.full_time }
    if pos.employment_type == "part-time" and "hours_per_week" in pos {
      label = label + ", " + str(pos.hours_per_week) + " " + goc_labels.hours_per_week
    }
    "(" + label + ")"
  }
  let format_term_range = (term) => {
    utils.strpdate(term.startDate) + " " + sym.dash.en + " " + (
      if term.endDate == "present" { content.ui.labels.present } else { utils.strpdate(term.endDate) }
    ) + " " + format_employment(term)
  }
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
      margin: 0.75in,
      footer: context [
          #set text(size: 11pt)
          #grid(
              columns: (1fr, 1fr),
              align(left)[#ui.labels.updated: #datetime.today().display("[year]-[month]-[day]")],
              align(right)[#ui.labels.page 
              #counter(page).display("1/1", both: true)]
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
    #text(fill: ubcblue)[#it.body] #box(width: 1fr, line(length: 100%, stroke: ubcblue + 0.5pt)) \
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
    #text(size: 18pt, font: "New Computer Modern", weight: "bold")[#content.personal.name] \
    #link("mailto:" + content.personal.email)[#content.personal.email] | #content.personal.phone | #link(content.personal.url)[#content.personal.url.split("//").at(1)] | #link("https://github.com/joshuah143")[github.com/joshuah143] \
    #if goc_mode and "address" in content.personal and content.personal.address != none [
      #content.personal.address \
    ]
    #if goc_mode and "pri" in content.personal and content.personal.pri != none [
      #goc_labels.pri: #content.personal.pri \
    ]
    #text(weight: "bold")[#content.personal.titles.at(0)] \
  ]

  // Skills section
  [= #eval(ui.sections.skills, mode: "markup")]

  for skill_item in content.skills {
    if skill_item.visible [
      #text(weight: "bold")[#skill_item.title] | #skill_item.description \
    ]
  }

  // Work experience section
  [= #ui.sections.work]

  for org in content.work {
    if not org.show { continue }
    if goc_mode and org.at("goc_show", default: true) == false { continue }
    for position in org.positions {
      if not position.show { continue }
      [
        #text(weight: "bold")[#position.position] \
        #org.organization
      ]
      if goc_mode and "goc_terms" in position {
        for term in position.goc_terms [
          \ #h(1em) #format_term_range(term)
        ]
        [\ ]
      } else [
        | #utils.strpdate(position.startDate) #sym.dash.en #if position.endDate == "present" { ui.labels.present } else { utils.strpdate(position.endDate) }
        #if goc_mode [ #format_employment(position) ]
        #if org.url != "" [
          | #link(org.url)[#org.url.split("//").at(1)]
        ]\
      ]
      if goc_mode and org.at("location", default: "") != "" [
        #h(1em) #emph(org.location) \
      ]
      for highlight in position.highlights [
        - #eval(highlight, mode: "markup") \
      ]
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

  // Advocacy section
  [= #ui.sections.advocacy]

  if "advocacy" in content {
    for role in content.advocacy {
      if role.visible != false [
        #split_job(
          title: role.position,
          company: role.organization,
          date: utils.strpdate(role.startDate) + " - " + (if role.endDate == "present" { ui.labels.present } else { utils.strpdate(role.endDate) }),
          actions: role.highlights,
          visible: true
        )
      ]
    }
  }

  // Experiences section
  [= #ui.sections.experiences]

  if "experiences" in content {
    for exp in content.experiences {
      if exp.visible [
        #achievement(
          focus: "\"" + exp.name + "\"",
          description: exp.description,
          visible: true
        )
      ]
    }
  }

   // Awards section
  [= #ui.sections.awards]

  if "awards" in content {
    for award_item in content.awards {
      if award_item.visible [
        #text(weight: "bold")[#award_item.title]
        #h(1fr) #utils.strpdate(award_item.date) \
        #for highlight in award_item.highlights [
          #highlight \
        ]
      ]
    }
  }
}
