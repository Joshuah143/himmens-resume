// Imported from Overleaf version

#let ubcblue = rgb("#002145")
#show link: underline
#set text(fallback: false)
#set text(font: "Open Sans", size: 11pt)
#show text.where(weight: "bold"): set text(fill: ubcblue)
#show text.where(weight: "regular"): set text(fill: rgb("#333333"))
#set grid.cell(align: top + left)

#show heading: it => [
  #text(fill: ubcblue)[#it.body] #box(width: 1fr, line(length: 100%, stroke: ubcblue + 0.5pt))
]

#let cv-mode = false
#let use_footer = true

#let ojob = (title: "", 
            company: "", 
            description: "",
            date: "", 
            actions: [],
            site: "",
            visible: true) => {
  if (visible or cv-mode) [ 
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

#let job = (title: "", 
            company: "", 
            description: "",
            date: "", 
            actions: [],
            site: "",
            visible: true) => {
  if (visible or cv-mode) {
    grid(columns: (1fr, 3fr), column-gutter: 10pt,  row-gutter: 0pt,
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

#let award = (title: "", 
             organization: "", 
             date: "", 
             description: [],
             visible: true) => {
  if (visible or cv-mode) [
    #text(weight:"bold")[#title] | #date \
    #description
  ]
}

#let skill = (title: "", 
             description: "",
             visible: true) => {
  if (visible or cv-mode) [
    #text(weight:"bold")[#title] | #description \
  ]
}

#let achievement = (focus: "", 
                    description: "",
                    visible: true) => {
  if (visible or cv-mode) [
    - #text(weight:"bold")[#focus] #description \
  ]
}

#set page(paper: "us-letter", footer: grid(columns: (50%, 50%), image("assets/cooplogo.png"), grid.cell(align: right+horizon)[#text(font: "Open Sans", weight: "bold")[science.coop\@ubc.ca | 604-822-9677]]), header: locate(loc => {
      if counter(page).at(loc).first() > 1 {
        return {text(weight: "bold")[Joshua Himmens - Resume]; box(width: 1fr, align(right)[*587 434 0118*])}
      }}))



// Begin actual resume
#align(center)[

#text(size: 15pt, font: "Open Sans", weight: "bold")[Joshua Himmens] \
#if cv-mode [
  #text(size: 10pt, font: "Open Sans", weight: "bold")[Curriculum Vitae \ ]
]
#link("mailto:joshua@himmens.com")[joshua\@himmens.com] | 587-434-0118 | #link("https://himmens.com")[https://himmens.com] \
#text(weight: "bold")[Undergraduate Engineering Physics Student] at The University of British Columbia\  
#text(weight: "bold")[92% (A+)] Average | #text(weight: "bold")[English] (Native), #text(weight: "bold")[French] (Working Knowledge)

]


= Technical/Research Experience

#job(
  title: "ATLAS Deep Learning Research Student",
  company: "TRIUMF",
  description: "ATLAS detects particles from the Large Hadron Collider colliding at 99.999999% the speed of light to explore the bounds of physics.",
  date: "05/2024 - Present",
  site: "himmens.com/triumf",
  actions: (
    "Developed panoptic segmentation models for the ATLAS detector using the PointNet ML framework with Wandb, TensorFlow, Keras.", 
    "Used CERN's grid computing to parallelize compute across thousands of nodes.",
    "Worked independently to develop models using cutting edge transfer learning approaches."),
  visible: true
)

#job(
  title: "Command and Data Handling (CDH) Lead and Firmware Developer",
  company: "UBC Orbit Satellite Team",
  description: "ALEASAT is an earth observation cubesat supported by the European Space Agency and UBC.",
  date: "10/2023 - Present",
  site: "himmens.com/orbit",
  actions: (
    "Led the CDH team to develop software to meet mission and testing objectives from ESA (European Space Agency) for the ALEASAT project.", 
    "Managed a team of 10 firmware developers.", 
    "Developed mission testing, function testing, and acceptance testing procedures.",
    "Programmed device drivers, electrical ground support equipment (EGSE).", 
    "Developed the ALEASAT Avionics Test Bench (FlatSat).", 
),
  visible: true
)

#job(
  title: "Embedded Firmware Developer",
  company: "UBC Orbit Satellite Team",
  date: "2023 - Present",
  actions: (
    "Programmed device drivers, electrical ground support equipment (EGSE).", 
    "Developed the ALEASAT Avionics Test Bench (FlatSat).", 
    "Worked on the ALEASAT onboard computer for launch in Q1 2026."),
  visible: false
)

#job(
  title: "Open Source Contributor",
  company: "NumPy",
  date: "2021",
  actions: (
    "Contributed to the open-source numerical analysis tool with 86 million monthly downloads.",),
  visible: false
)

#job(
  title: "Elections Officer",
  company: "Elections Alberta",
  date: "2023",
  actions: (
    "Integrated as part of a team to run a safe and fair provincial election", 
    "Managed public interactions and vote counting."),
  visible: false
)

#job(
  title: "International Baccalaureate Student",
  company: "Western Canada High School",
  date: "2020 - 2023",
  actions: (
    "Took the IB diploma program with higher-level Math, Physics, and Chemistry", 
    "Completed an Extended Essay on simulations of the brachistochrone problem in physics."),
  visible: false
)

#job(
  title: "National Youth Spokesperson",
  company: "Scouts Canada",
  date: "2017 - 2022",
  actions: (
    "Hosted events", 
    "Authored articles", 
    "Managed social media", 
    "Engaged with media outlets."),
  visible: false
)

#job(
  title: "Committee Member",
  company: "Scouts Canada Sustainable Development Goals Program",
  date: "2019 - 2020",
  actions: (
    "Assisted in creating programs for Sustainable Development Goals education and outreach.",),
  visible: false
)



= Publications and Presentations

Co-author of #text(weight: 
"bold")[Implementing Low-Cost ADCS for 1U CubeSat: Insights from ALEASAT] to be presented at the International Aeronautical Conference (IAC) in October 2024.

Presented #text(weight: "bold")[3D Particle Flow in the ATLAS Calorimeter: How to Train Your Model], a speed-talk, at the 2024 TRIUMF Science Week

Presented #text(weight: "bold")[ALEASAT ESA "Fly Your Satellite!" Training Week Presentation] at the European Space Agency's ESEC-GALAXIA (Transinne Belgium) in 2024 as part of the "Fly Your Satellite 4!" program.

= Technical Skills


#skill(
  title: "Machine Learning",
  description: "Experienced using TensorFlow, Keras, PointNet, Weights and Biases (wandb) for model development."
)
#skill(
  title: "Embedded Programming",
  description: "Experienced with FreeRTOS on TMS570 and RP2040."
)
#skill(
  title: "Quantum Computing",
  description: "Used Qiskit to simulate quantum algorithms."
)

= Awards

#award(
  title: "Erich Vogt First Year Summer Research Experience (FYSRE) Award",
  date: "2024",
  description: ("Awarded to promising students in physics for a 4 month research placement."),
  visible: true)

#award(
  title: "Alberta Centennial Award and Alberta Premier's Citizenship Award",
  date: "2023",
  description: ("Awarded for outstanding community service. Value: $2000"),
  visible: true)

#award(
  title: "Calgary Flames Foundation Community Involvement Scholarship",
  date: "2023",
  description: ("Awarded for community involvement. Value: $2005"),
  visible: true)

#award(
  title: "Julia Turnbull Leadership Award for exceptional community service",
  date: "2023",
  description: ("Awarded for exceptional community service. Value: $1000"),
  visible: true)

#award(
  title: "Ted Rogers Entrance Scholarship",
  date: "2023",
  description: ("Awarded for academic achievement. Value: $2000"),
  visible: true)

#award(
  title: "Tom Lawson award for embodying the spirit of Canadian debate",
  date: "2023",
  description: ("Awarded for embodying the spirit of Canadian debate. Required a vote of the student delegates at the Canadian National Debate Seminar."),
  visible: true)

#award(
  title: "10 Scouts Canada commendations",
  date: "2017 - 2022",
  description: ("Awarded for various achievements."),
  visible: false)

= Advocacy and Leadership

#job(
  title: "Curriculum and Advocacy Director",
  company: "UBC Engineering Undergraduate Society",
  date: "2024 - Present",
  actions: (
    "Worked with the faculty and the undergraduate society to develop multi-year plans for coop-related advocacy.", 
    "Advocated for transparency in coop fee use in line with standards at other institutions."),
  visible: true
)

#job(
  title: "Advisory Team Member",
  company: "Child Rights Connect",
  date: "2021 - 2023",
  actions: (
    "Provided guidance to UN delegations on communication strategies for high-level rights goals.", 
    "Presented to governments and consulted on international initiatives to support the UN Convention on the Rights of the Child."),
  visible: true
)

#job(
  title: "Correspondent",
  company: "Organization of American States",
  date: "2019 - 2020",
  actions: (
    "Created and edited content on human and child rights in the Americas.", 
    "Attended the 3rd Pan American Child and Youth Forum in Cartagena, Colombia with the Government of Canada."),
  visible: true
)

= Experiences

#achievement(
  focus: "\"Quantum School for Young Students\"",
  description: "participant at the University of Waterloo and Institute for Quantum Computing.",
  visible: true
)

#achievement(
  focus: "\"Introduction to Quantum Computing\"",
  description: "participant, an 8-month course on quantum computing using IBM's quantum infrastructure.",
  visible: true
)

#achievement(
  focus: "\"GoPhysics!\"",
  description: "participant, a physics enrichment program at the Perimeter Institute.",
  visible: false
)

#achievement(
  focus: "B2 French proficiency",
  description: "(B1 DELF certified).",
  visible: false
)

#achievement(
  focus: "Public speaker",
  description: "on children's rights and youth engagement, with audiences ranging from 100-1000 people.",
  visible: false
)

#achievement(
  focus: "Placed 4th nationally",
  description: "in Canadian National style debate in 2023.",
  visible: false
)

#achievement(
  focus: "Scientific Computing with Python certification",
  description: "(300 hours).",
  visible: true
)

#achievement(
  focus: "National Debate Semi-Finalist",
  description: "Canadian National Style, 2023.",
  visible: false
)


