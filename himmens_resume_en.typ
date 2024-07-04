// Imported from Overleaf version

#let ubcblue = rgb("#002145")
// #show link: underline
#set text(fallback: false)
#set text(font: "Open Sans", size: 10pt)
#show text.where(weight: "bold"): set text(fill: ubcblue)
#show text.where(weight: "regular"): set text(fill: rgb("#333333"))
#let cv-mode = false

#show heading: it => [
  #text(fill: ubcblue)[#it.body] #box(width: 1fr, line(length: 100%, stroke: ubcblue + 0.5pt))
]


#let job = (title: "", 
            company: "", 
            date: "", 
            actions: [],
            visible: true) => {
  if (visible == true or cv-mode == true) [
    #text(size: 12pt, weight:"bold")[#title] \
    #company | #date \
    #for action in actions [
      - #text(size: 10pt)[#action] \
    ]
  ]
  }

#let award = (title: "", 
             organization: "", 
             date: "", 
             description: [],
             visible: true) => {
  if (visible == true or cv-mode == true) [
    #text(weight:"bold")[#title] | #date \
    #description
  ]
  }

#set page(footer: grid(columns: (50%, 50%), image("assets/cooplogo.png"), grid.cell(align: right+horizon)[#text(font: "Open Sans", size: 12pt, weight: "bold")[science.coop\@ubc.ca | 604-822-9677]]), header: locate(loc => {
      if counter(page).at(loc).first() > 1 {
        return {text(weight: "bold")[Joshua Himmens - Resume]; box(width: 1fr, align(right)[*587 434 0118*])}
      }}))



// Begin actual resume
#align(center)[

#text(size: 16pt, font: "Open Sans", weight: "bold")[Joshua Himmens] \
#link("mailto:joshua@himmens.com")[joshua\@himmens.com] | 587 434 0118 | #link("https://himmens.com")[himmens.com] \
#text(weight: "bold")[ATLAS Deep Learning Research Student at TRIUMF\ Undergraduate Engineering Physics Student at The University of British Columbia]
]


= Experience

#job(
  title: "ATLAS Deep Learning Research Student",
  company: "TRIUMF",
  date: "Summer 2024",
  actions: ("Developed panoptic segmentation models for the ATLAS detector using the PointNet ML framework with Wandb, TensorFlow, Keras", "Used CERN's grid computing to parallelize compute across thousands of nodes."),
  visible: true
)

#job(
  title: "Command and Data Handling (CDH) Lead",
  company: "UBC Orbit Satellite Team",
  date: "2024 - Present",
  actions: ("Led the CDH team to develop software to meet mission and testing objectives from ESA (European Space Agency) for the ALEASAT project", "Managed a team of 10", "Presented to ESA in Belgium on project status", "Developed mission testing, function testing, and acceptance testing procedures."),
  visible: true
)

#job(
  title: "Embedded Firmware Developer",
  company: "UBC Orbit Satellite Team",
  date: "2023 - Present",
  actions: ("Programmed device drivers, electrical ground support equipment (EGSE)", "Developed the ALEASAT Avionics Test Bench (FlatSat)", "Worked on the ALEASAT onboard computer for launch in Q1 2026."),
  visible: true
)

#job(
  title: "Curriculum and Advocacy Director",
  company: "UBC Engineering Undergraduate Society",
  date: "2024 - Present",
  actions: ("Worked with the faculty and the undergraduate society to develop multi-year plans for coop-related advocacy", "Advocated for transparency in coop fee use in line with standards at other institutions."),
  visible: true
)

#job(
  title: "Advisory Team Member",
  company: "Child Rights Connect",
  date: "2021 - 2023",
  actions: ("Provided guidance to UN delegations on communication strategies for high-level rights goals", "Presented to governments and consulted on international initiatives to support the UN Convention on the Rights of the Child."),
  visible: true
)

#job(
  title: "Correspondent",
  company: "Organization of American States",
  date: "2019 - 2020",
  actions: ("Created content on human and child rights", "Attended international conferences representing Canada", "Attended the 3rd Pan American Child and Youth Forum in Cartagena, Colombia with the Government of Canada."),
  visible: true
)

#job(
  title: "Open Source Contributor",
  company: "NumPy",
  date: "2021",
  actions: ("Contributed to the open-source numerical analysis tool with 86 million monthly downloads.",),
  visible: false
)

#job(
  title: "Elections Officer",
  company: "Elections Alberta",
  date: "2023",
  actions: ("Integrated as part of a team to run a safe and fair provincial election", "Managed public interactions and vote counting."),
  visible: false
)

#job(
  title: "International Baccalaureate Student",
  company: "Western Canada High School",
  date: "2020 - 2023",
  actions: ("Took the IB diploma program with higher-level Math, Physics, and Chemistry", "Completed an Extended Essay on simulations of the brachistochrone problem in physics."),
  visible: false
)

#job(
  title: "National Youth Spokesperson",
  company: "Scouts Canada",
  date: "2017 - 2022",
  actions: ("Hosted events", "Authored articles", "Managed social media", "Engaged with media outlets."),
  visible: false
)

#job(
  title: "Committee Member",
  company: "Scouts Canada Sustainable Development Goals Program",
  date: "2019 - 2020",
  actions: ("Assisted in creating programs for Sustainable Development Goals education and outreach.",),
  visible: false
)

= Education

= Publications

= Technical Skills

= Awards

#award(
  title: "Erich Vogt First Year Summer Research Experience (FYSRE) award",
  date: "2024",
  description: ("Awarded for exceptional research in the field of physics."),
  visible: true)

#award(
  title: "Tom Lawson award for embodying the spirit of Canadian debate",
  date: "2023",
  description: ("Awarded for embodying the spirit of Canadian debate."),
  visible: true)

#award(
  title: "Alberta Premier's Citizenship Award for outstanding community service",
  date: "2023",
  description: ("Awarded for outstanding community service."),
  visible: true)

#award(
  title: "Calgary Flames Foundation Community Involvement Scholarship",
  date: "2023",
  description: ("Awarded for community involvement."),
  visible: true)

#award(
  title: "Julia Turnbull Leadership Award for exceptional community service",
  date: "2023",
  description: ("Awarded for exceptional community service."),
  visible: true)

#award(
  title: "Ted Rogers Entrance Scholarship for academic achievement",
  date: "2023",
  description: ("Awarded for academic achievement."),
  visible: true)

#award(
  title: "10 Scouts Canada commendations",
  date: "2017 - 2022",
  description: ("Awarded for various achievements."),
  visible: false)

= Other

National Debate Semi-Finalist, Canadian National Style, 2023.
