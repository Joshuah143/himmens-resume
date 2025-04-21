#import "utils.typ"

#let uservars = (
    headingfont: "Calibri", //"Linux Libertine",
    bodyfont: "Calibri", //"Linux Libertine",
    fontsize: 10pt, // 10pt, 11pt, 12pt
    linespacing: 6pt,
    sectionspacing: 0pt,
    showAddress:  true, 
    showNumber: true,  
    showTitle: true,   
    headingsmallcaps: true, 
    sendnote: false, 
    breakable: false, 
)

#set page(
    paper: "us-letter", // a4, us-letter
    numbering: "1 / 1",
    number-align: center, // left, center, right
    margin: 1.25cm, // 1.25cm, 1.87cm, 2.5cm
)

#set text(
    font: uservars.bodyfont,
    size: uservars.fontsize,
    hyphenate: false,
)

#set list(
    spacing: uservars.linespacing
)

#set par(
    leading: uservars.linespacing,
    justify: true,
)

#show heading.where(
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

#show heading.where(
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

// Job titles
#let jobtitletext(info, uservars) = {
    if ("titles" in info.personal and info.personal.titles != none) and uservars.showTitle {
        block(width: 100%)[
            *#info.personal.titles.join("  /  ")*
            #v(-4pt)
        ]
    } else {none}
}

#let contacttext(info, uservars) = block(width: 100%)[
    #let profiles = (
        if "email" in info.personal and info.personal.email != none { box(link("mailto:" + info.personal.email)) },
        if ("phone" in info.personal and info.personal.phone != none) and uservars.showNumber {box(link("tel:" + info.personal.phone))} else {none},
        if ("url" in info.personal) and (info.personal.url != none) {
            box(link(info.personal.url)[#info.personal.url.split("//").at(1)])
        }
    ).filter(it => it != none) 

    #if ("profiles" in info.personal) and (info.personal.profiles.len() > 0) {
        for profile in info.personal.profiles {
            profiles.push(
                box(link(profile.url)[#profile.url.split("//").at(1)])
            )
        }
    }

    #set text(font: uservars.bodyfont, weight: "medium", size: uservars.fontsize)
    #pad(x: 0em)[
        #profiles.join([ #sym.union ])
    ]
]

#let content = yaml("cv_content.yaml")


// Headers
#align(center)[
    = #content.personal.name
    #jobtitletext(content, uservars)
    #contacttext(content, uservars)
]

// Work
#{
    if ("work" in content) and (content.work != none) {block[
        == Work Experience
        #for w in content.work {
            if w.show != true {continue}
            block(width: 100%, breakable: uservars.breakable)[
                // Line 1: Company and Location
                #if ("url" in w) and (w.url != none) [
                    *#link(w.url)[#w.organization]* #h(1fr) *#w.location* \
                ] else [
                    *#w.organization* #h(1fr) *#w.location* \
                ]
            ]
            // Create a block layout for each work entry
            let index = 0
            for p in w.positions {
                if p.show != true {continue}
                if index != 0 {v(0.6em)}
                block(width: 100%, breakable: uservars.breakable, above: 0.6em)[
                    // Parse ISO date strings into datetime objects
                    #let start = utils.strpdate(p.startDate)
                    #let end = utils.strpdate(p.endDate)
                    // Line 2: Position and Date Range
                    #text(style: "italic")[#p.position] #h(1fr)
                    #utils.daterange(start, end) \
                    // Highlights or Description
                    #for hi in p.highlights [
                        - #eval(hi, mode: "markup")
                    ]
                ]
                index = index + 1
            }
        }
    ]}
}


// Education

// Leadership

// Awards
#{
    if ("awards" in content) and (content.awards != none) {block[
        == Honors and Awards
        #for award in content.awards {
            // Parse ISO date strings into datetime objects
            let date = utils.strpdate(award.date)
            // Create a block layout for each award entry
            block(width: 100%, breakable: uservars.breakable)[
                // Line 1: Award Title and Value
                #if ("value" in award) and (award.value != none) [                   
                    *#award.title*  (\$#award.value) \
                ] else [
                    *#award.title* \
                ]
                // Line 2: Issuer and Date
                Issued by #text(style: "italic")[#award.issuer]  #h(1fr) #date \
                // Summary or Description
                #if ("highlights" in award) and (award.highlights != none) {
                    for hi in award.highlights [
                        - #eval(hi, mode: "markup")
                    ]
                } else {}
            ]
        }
    ]}
}