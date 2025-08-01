require ["include", "environment", "variables", "relational", "comparator-i;ascii-numeric", "spamtest"];
require ["fileinto", "extlists", "imap4flags", "vnd.proton.expire", "regex"];
require ["date", "relational", "vnd.proton.eval"];

#      ▗     
#  ▛▘█▌▜▘▌▌▛▌
#  ▄▌▙▖▐▖▙▌▙▌
#          ▌ 
                           
# Makes sure expire does not persist if we are running a full-inbox test,
# so items incorrectly expired during testing aren't lost.
# Comment this out if you don't want existing expiring emails to be reset,
# or once you have finished testing or setting up new filters.
unexpire;

#        ▘  ▌ ▜     
#  ▌▌▀▌▛▘▌▀▌▛▌▐ █▌▛▘
#  ▚▘█▌▌ ▌█▌▙▌▐▖▙▖▄▌
#                   

# Relative dates are set up to work in days, so we can parse and compare using julian days method.

# From how long ago do you want to get prompted to migrate old accounts?
set "migration_date_in_days_ago" "0";

set "newsletter_expiry_days" "90";

set "screened_out_expiry_days" "30";

# on initial run for inbox cleanup, if a newsletter should already be expired,
# do we want a grace period to have the chance to check first?
set "expiry_grace_period_days" "7";

# Note: 730 (2 years) is the max expiration period supported by Proton (undocumented >:( )
# If you set to eg 1500, it will set to 730,
# but if you set to 2000, it just doesn't set it.
set "paper_trail_expiry_days" "730";
set "non_critical_alerts_expiry_days" "7";

# Current date
if currentdate :zone "+0000" :matches "julian" "*" {
  set "current_julian_day" "${1}";
}

# Received date
if date :zone "+0000" :matches "received" "julian" "*" {
  set "received_julian_day" "${1}";
}

# Migration date
set :eval "mail_age_in_days" "${current_julian_day} - ${received_julian_day}";
set :eval "migration_julian_day" "${current_julian_day} - ${migration_date_in_days_ago}";

# Relative expiration dates
# Expire newsletters and paper trail from the day they were received
# Warning - this will expire existing emails for initial inbox cleanup.
if string :comparator "i;ascii-numeric" :value "ge" "${mail_age_in_days}" "${newsletter_expiry_days}" {
  # initial test run
  set "newsletter_expiry_relative_days" "${expiry_grace_period_days}";
} else {
  # usual behavior for new incoming emails
  set :eval "newsletter_expiry_relative_days" "-${mail_age_in_days} + ${newsletter_expiry_days}";
}

if string :comparator "i;ascii-numeric" :value "ge" "${mail_age_in_days}" "${paper_trail_expiry_days}" {
  # initial test run
  set "paper_trail_expiry_relative_days" "${expiry_grace_period_days}";
} else {
  # usual behavior for new incoming emails
  set :eval "paper_trail_expiry_relative_days" "-${mail_age_in_days} + ${paper_trail_expiry_days}";
}

# Validation
# Keep a 'sieve issue' label present in the inbox, just as a catchall flag
if not allof(
  # If today is not gte 0 AND received is not gte 0 AND mailAge (today - received) is not gte 0
  # in other words:
  # if today is older than 31-Dec-1999 OR received-by is older than 31-Dec-1999 OR mailAge is...negative?
  string :comparator "i;ascii-numeric" :value "ge" "${current_julian_day}" "0",
  string :comparator "i;ascii-numeric" :value "ge" "${received_julian_day}" "0",
  string :comparator "i;ascii-numeric" :value "ge" "${mail_age_in_days}" "0"
) {
  fileinto "needs admin";
  stop;
}

#                 ▘          
#  ▛▘▛▌▀▌▛▛▌  ▟▖  ▌▛▌▛▌▛▌▛▘█▌
#  ▄▌▙▌█▌▌▌▌  ▝   ▌▙▌▌▌▙▌▌ ▙▖
#    ▌             ▄▌        

# IGNORED - spam; this is Proton's default spam sieve filter.
if allof (
  environment :matches "vnd.proton.spam-threshold" "*",
  spamtest :value "ge" :comparator "i;ascii-numeric" "${1}"
) {
  stop;
}

# IGNORED - sent items
if allof(
  anyof(
    header :list "from" [":addrbook:personal?label=My Addresses", ":addrbook:personal?label=Old Addresses"]
  ),
  not header :comparator "i;unicode-casemap" :regex [
      "from",
      "to",
      "X-Original-To"
    ] [
    "^([a-zA-Z0-9]{1,})\\.([a-zA-Z]{1,})(\\.[a-zA-Z]{1,})?@passmail\.com$",
    "^([a-zA-Z0-9]{1,})\\.([a-zA-Z]{1,})(\\.[a-zA-Z]{1,})?@passmail\.net$",
    "^([a-zA-Z0-9]{1,})\\.([a-zA-Z]{1,})(\\.[a-zA-Z]{1,})?@passinbox\.com$",
    "^([a-zA-Z0-9]{1,})\\.([a-zA-Z]{1,})(\\.[a-zA-Z]{1,})?@passfwd\.com$"
    ]
 ) {
  stop;
}

#                 ▌      ▗ 
#  ▛▘▛▘▛▘█▌█▌▛▌█▌▛▌▄▖▛▌▌▌▜▘
#  ▄▌▙▖▌ ▙▖▙▖▌▌▙▖▙▌  ▙▌▙▌▐▖
#     

# Screened Out - Screened Out contacts
if anyof(
header :list [
  "from",
  "to",
    "X-Original-To"] ":addrbook:personal?label=Screened Out",
header :comparator "i;unicode-casemap" :is "to" "[EMAIL_TO_SCREEN_TO]"
) {
  expire "day" "${screened_out_expiry_days}";
  addflag "\\Seen";
  fileinto "expiring";
  fileinto "Trash";
  stop;
}

# Screened Out - Political Campaign lists
if header :comparator "i;unicode-casemap" :contains "list-unsubscribe" [
  "ngpvan", # used by Democratic Party; fun fact!  it's now owned by private equity firm, "Apax Partners". Surprise, surprise... :/
  "actionkit" # a subsidiary of ngpvan
  ] 
{
  expire "day" "${screened_out_expiry_days}";
  addflag "\\Seen";
  fileinto "expiring";
  fileinto "Trash";
  stop;
}

# Screened Out - Craigslist
if header :comparator "i;unicode-casemap" :matches [
  "from",
  "X-Simplelogin-Original-From"
  ] [
    "*craigslist*"
  ] {
  fileinto "craigslist";
  if header :comparator "i;unicode-casemap" :matches [
    "from",
    "X-Simplelogin-Original-From"
    ] [
    "*automated*message*"
  ] {
    # Posting notification; I manage these via my craigslist app
    expire "day" "${screened_out_expiry_days}";
    addflag "\\Seen";
    fileinto "expiring";
    fileinto "Screened Out"; 
  }
  stop;
}

# Screened Out - calendar items

# CALENDAR - Google calendar auto-emails
if anyof(
  header :comparator "i;unicode-casemap" :matches [
    "from",
    "X-Simplelogin-Original-From"
    ] [
    "*calendar-notification@google.com*"
  ],
  header :comparator "i;unicode-casemap" :regex ["Subject"] [ 
    ".*accepted:.*",
    ".*cancellation.*event.*",
    ".*notification.*@.*",
    ".*reminder.*event.*"
]) {
  expire "day" "${screened_out_expiry_days}";
  fileinto "calendar";
  fileinto "expiring";
  if header :comparator "i;unicode-casemap" :matches ["subject"] [
    "*accepted:*"
  ] {
    addflag "\\Seen";
    fileinto "Screened Out";
  }
  stop;
}

#     ▌ ▌  ▜   ▌   ▜   
#  ▀▌▛▌▛▌  ▐ ▀▌▛▌█▌▐ ▛▘
#  █▌▙▌▙▌  ▐▖█▌▙▌▙▖▐▖▄▌
#                      

# LABEL DECORATION - taxes
if allof(
  header :comparator "i;unicode-casemap" :regex [
    "from",
    "X-Simplelogin-Original-From",
    "subject"
  ] [
    ".*(^|[^a-zA-Z0-9])tax(ed|able|ation)?([^a-zA-Z0-9]|$).*",
    ".*IRS.*" # this is catching stuff with "irs" in it that isn't "internal revenue service"... duh. :P
  ],
  not header :comparator "i;unicode-casemap" :matches ["subject"] [
    "*sales*"
  ]) {
  fileinto "taxes";
}

# LABEL DECORATION - that one movie theatre (ie. a place I want labeled SPECIFICALLY because I'm too lazy to use the search bar
if header :comparator "i;unicode-casemap" :regex [
    "from",
    "X-Simplelogin-Original-From",
    "subject"
    ] [
      ".*movieTheater.*"
  ]  {
    fileinto "movieTheater";
}

# LABEL DECORATION - conversations
if anyof ( 
header :comparator "i;unicode-casemap" :regex "subject" [
  # <LABEL DECORATION - conversations>
  ".*fw: .*",
  ".*fwd: .*",
  ".*re: .*"
  # </LABEL DECORATION - conversations>
], header :list "from" [":addrbook:personal?label=Friends", ":addrbook:personal?label=Family", ":addrbook:personal?label=ETC"],
    header :contains "In-Reply-To" "@my-domain.com",
    header :is "List-Id" "[list-id]")
 {
  fileinto "conversations";
}

# LABEL DECORATION - reservations (I condensed this because too many labels
if anyof(
  header :comparator "i;unicode-casemap" :matches "subject" [
    "*booking*",
    "*reservation*"],
  header :comparator "i;unicode-casemap" :matches "from" [
    # some of these generate unique email addresses so can't be managed through Proton UI
    "*agoda*",
    "*airbnb*",
    "*booking.com*",
    "*kayak.com",
    "*skyscanner*"
    ],
allof(
  header :comparator "i;unicode-casemap" :matches "subject" [
    "*boarding*",
    "*flight*"
  ],

  header :comparator "i;unicode-casemap" :regex "subject" [
    ".*(^|[^a-zA-Z0-9])pass([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])itinerary([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])id([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])your([^a-zA-Z0-9]|$).*"
  ]
), allof(
    header :comparator "i;unicode-casemap" :regex [
      "from",
      "X-Simplelogin-Original-From",
      "subject"
      ] [
        ".*(^|[^a-zA-Z0-9])bus(es)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])ferr(y|ies)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])train([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])rail([^a-zA-Z0-9]|$).*"
    ],
    header :comparator "i;unicode-casemap" :matches "subject" [
      "*book*",
      "*confirm*",
      "*itinerary*",
      "*reserv*"
    ]
  ), allof(
  header :comparator "i;unicode-casemap" :regex [
    "from",
    "X-Simplelogin-Original-From",
    "subject"
    ] [
      ".*(^|[^a-zA-Z0-9])ferr(y|ies)([^a-zA-Z0-9]|$).*"
  ],
  header :comparator "i;unicode-casemap" :matches "subject" [
    "*book*",
    "*confirm*",
    "*itinerary*",
    "*reserv*"
  ]
), allof(
    header :regex "subject" [
      ".*(^|[^a-zA-Z0-9])[aA]ccommodation([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])HI([^a-zA-Z0-9]|$).*", # Hostelling International
      ".*(^|[^a-zA-Z0-9])[hH]os?tel([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])resort(s)?([^a-zA-Z0-9]|$).*"
    ],

    header :comparator "i;unicode-casemap" :matches "subject" [
      "*book*",
      "*confirm*",
      "*reserv*"
    ]
  )
  )
{
  fileinto "reservations";
}

# LABEL DECORATION - calendar
if header :comparator "i;unicode-casemap" :matches [
  "from",
  "X-Simplelogin-Original-From",
  "subject"
  ] [
  "*calendar*"
  ] {
    fileinto "calendar";
}


#    ▜     ▗   
#  ▀▌▐ █▌▛▘▜▘▛▘
#  █▌▐▖▙▖▌ ▐▖▄▌
#              

# ALERTS - Potentially serious security alerts
if allof(
  not header :comparator "i;unicode-casemap" :matches "subject" [
    "*benefits*",
    "*deposit*", # No "security deposit"
    "*offer*" # no "declined offer"
  ],
  header :comparator "i;unicode-casemap" :matches "subject" [
    "*breach*",
    "*card*not*",
    "*declin*",
    "*identity*",
    "*fraud*",
    "*large purchase*",
    "*security*"
  ]
) {
  fileinto "Alerts";
  fileinto "security";
  if string :comparator "i;ascii-numeric" :value "ge" "${received_julian_day}" "${migration_julian_day}" {
    fileinto "inbox";
  }
  stop;
}

# ALERTS - failed email deliveries
if allof(
  header :comparator "i;unicode-casemap" :matches [
    "from", 
    "X-Simplelogin-Original-From"
    ] [
    "*mail delivery subsystem*"
  ],

  header :comparator "i;unicode-casemap" :matches "subject" [
    "*delivery status*"
  ]
) {
  expire "day" "${non_critical_alerts_expiry_days}";
  fileinto "expiring";
  fileinto "Alerts";
  if string :comparator "i;ascii-numeric" :value "ge" "${received_julian_day}" "${migration_julian_day}" {
    fileinto "inbox";
  }
  stop;
}

# ALERTS - transit
if header :list "from" ":addrbook:personal?label=Transit" {
  expire "day" "${non_critical_alerts_expiry_days}";
  fileinto "expiring";
  addflag "\\Seen";
  fileinto "Alerts/Transit";
  stop;
}
# LABEL DECORATION - Google Alerts 
if address :all :comparator "i;unicode-casemap" :contains "From" ["googlealerts-noreply@google.com"]
{
    expire "day" "${non_critical_alerts_expiry_days}";
  fileinto "expiring";
  addflag "\\Seen";
  fileinto "Alerts";
  stop;
}

# ALERTS - discount codes (long expiration)
if allof(
  header :comparator "i;unicode-casemap" :regex "subject" [
    ".*(^|[^a-zA-Z0-9])[0-9]{1,3}%([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])coupon([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])discount([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])sale([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])voucher([^a-zA-Z0-9]|$).*"
  ],
  not header :comparator "i;unicode-casemap" :regex "subject" [
    ".*(^|[^a-zA-Z0-9])download([^a-zA-Z0-9]|$).*"
  ], not header :list ["from", "to", "X-Original-To", "Cc", "Bcc"] [":addrbook:personal?label.ends-with=Politics"] ) {
    fileinto "shopping";
    fileinto "Alerts";
    expire "day" "${paper_trail_expiry_relative_days}";
    fileinto "expiring"; 
    if string :comparator "i;ascii-numeric" :value "ge" "${received_julian_day}" "${migration_julian_day}" {
      fileinto "inbox";
  }
  stop;
}


# ALERTS - exclusions
if allof(
  not header :list [
  "from",
  "to",
  "X-Original-To"] ":addrbook:personal?label=Conversations",
  anyof (
    # exclude all statements, unless annual
    not header :comparator "i;unicode-casemap" :regex "Subject" ".*(^|[^a-zA-Z0-9])statement([^a-zA-Z0-9]|$).*", 
    header :comparator "i;unicode-casemap" :regex "Subject" ".*(^|[^a-zA-Z0-9])annual([^a-zA-Z0-9]|$).*"
  ),
  anyof(
    # exclude tips, unless flagged as important
    not header :comparator "i;unicode-casemap" :regex "Subject" ".*(^|[^a-zA-Z0-9])tip(s)?([^a-zA-Z0-9]|$).*", 
    header :comparator "i;unicode-casemap" :regex "Subject" ".*(^|[^a-zA-Z0-9])important([^a-zA-Z0-9]|$).*"
  ),
  not header :comparator "i;unicode-casemap" :regex "subject" [
    ".*(^|[^a-zA-Z0-9])(associate|report).*id([^a-zA-Z0-9]|$).*", # Amazon associates reports
    ".*(^|[^a-zA-Z0-9])bill.*review([^a-zA-Z0-9]|$).*", # exclude "your bill is ready for review"
    ".*(^|[^a-zA-Z0-9])get started([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])Fidelity Alerts: EFT([^a-zA-Z0-9]|$).*",
    # <copy LABEL DECORATION - conversations>
    ".*fw: .*",
    ".*fwd: .*",
    ".*re: .*"
    # </copy LABEL DECORATION - conversations>
  ]) {


  # ALERTS - reviews, basket prompts
  if allof(
    not header :comparator "i;unicode-casemap" :regex "Subject" [
      ".*(^|[^a-zA-Z0-9])activity([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])credit([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])feedback sports    ([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])information([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])interest([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])savings([^a-zA-Z0-9]|$).*"
    ],
    header :comparator "i;unicode-casemap" :regex "Subject" [
      ".*(^|[^a-zA-Z0-9])feedback([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])rat(e|ing)([^a-zA-Z0-9]|$).*", 
      ".*(^|[^a-zA-Z0-9])review(ing|s)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])tell us([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])waiting for you([^a-zA-Z0-9]|$).*"
    ]
  ) {
    fileinto "Alerts";
    fileinto "needs admin";
    if string :comparator "i;ascii-numeric" :value "ge" "${received_julian_day}" "${migration_julian_day}" {
      fileinto "inbox";
    }
    stop;
  }

  # ALERTS - single words
  if allof(
    not header :comparator "i;unicode-casemap" :regex [
      "Subject",
      "From",
      "To",
      "X-Simplelogin-Original-From",
      "X-Simplelogin-Envelope-To"
      ] [
      ".*(^|[^a-zA-Z0-9])event([^a-zA-Z0-9]|$).*", # exclude Eventbrite Visa meeting invites
      ".*(^|[^a-zA-Z0-9])issue [0-9]([^a-zA-Z0-9]|$).*", # excluding newsletter issues
      ".*(amazon|lyft|uber).*", # these cancellations can go to Paper Trail
      ".*(^|[^a-zA-Z0-9])ending in([^a-zA-Z0-9]|$).*", # not 'account ending in'
      ".*(^|[^a-zA-Z0-9])safestor policy (auto-)?renewal([^a-zA-Z0-9]|$).*", # safestor monthly renewals can go to Paper Trail
      ".*sign up.*" # asking you to sign up for text alerts
    ],
    # sole words sufficient to indicating attention is needed
    header :comparator "i;unicode-casemap" :regex "Subject" [
      ".*(^|[^a-zA-Z0-9])action([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])alert(s|ed|ing)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])can('?t| ?not)([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])cancell?(ed|ing)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])chang(e|ed|ing)([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])connect(e|ed|ing)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])could[n ']n?o?'?t([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])decision([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])did you mean([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])disclosure([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])dispute([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9-])end(s|ing)([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])expir(y|ed|es|ing|ation)([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])fail([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])hold([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])impact(ed)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])important([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])issue([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])multiple([^a-zA-Z0-9]|$).*",
      # traveling mailbox - item has been received and scanned, not just received
      ".*(^|[^a-zA-Z0-9])traveling mailbox: new mail([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])(new|you|now).*owner([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])outstanding([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])primary([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])reactivate(d)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])reschedule(d)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])remind(er)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])remove(d)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])requir([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])renew(al|ing)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])reversal([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])review([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])revision([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])safety([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])sensitive([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])service[^a-zA-Z0-9].*[^a-zA-Z0-9]end([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])tr(y|ied|ing)([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])unable([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])unusual([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])urgent([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])were(n'?t| not)([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])will not([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])won'?t([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])visas?([^a-zA-Z0-9]|$).*"
    ]
  ) {
    fileinto "alerts";
    if string :comparator "i;ascii-numeric" :value "ge" "${received_julian_day}" "${migration_julian_day}" {
      fileinto "inbox";
    }
    stop;
  }

  # ALERTS - requiring action
  if anyof(
    header :comparator "i;unicode-casemap" :regex "subject" 
    [
      ".*(^|[^a-zA-Z0-9])code: [0-9]{4,}([^a-zA-Z0-9]|$).*",  # Monarch code: 234324
      ".*(^|[^a-zA-Z0-9])pin code([^a-zA-Z0-9]|$).*",  # 'Pin code for order status check'
      ".*(^|[^a-zA-Z0-9])your code([^a-zA-Z0-9]|$).*",  # "Here is your code" (don't add your to main limbs, too broad)
      ".*(^|[^a-zA-Z0-9])sign in ?to([^a-zA-Z0-9]|$).*"  # email login links
    ],
    allof(
      header :comparator "i;unicode-casemap" :regex "subject" [
        ".*(^|[^a-zA-Z0-9])account([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])autopay([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])browser([^a-zA-Z0-9]|$).*",
        ".*card.*", # allows for Mastercard®
        ".*(^|[^a-zA-Z0-9])code([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])device([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])email([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])link([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])log[ -]?in([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])pass(code|key|word)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])profile([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])rent payment([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])sign[ -][io]n([^a-zA-Z0-9]|$).*"
      ],
      header :comparator "i;unicode-casemap" :regex "subject" [
        ".*(^|[^a-zA-Z0-9])activat(e|ed|ion)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])add(ed|ing)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])approve(d)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])authenticat(e|ed|ion)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])chang(e|ed|ing)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])confirm(ed|ing)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])identification([^a-zA-Z0-9]|$).*", # "Your Requested Online Banking Identification Code"
        ".*(^|[^a-zA-Z0-9])linked([^a-zA-Z0-9]|$).*", # "now linked in your account" versus download link
        ".*(^|[^a-zA-Z0-9])log(ged | |-)?in([^a-zA-Z0-9]|$).*", # allows for 'login code' or 'link to login', but not 'code' here as too broad
        ".*(^|[^a-zA-Z0-9])one[ -]time([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])new([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])set up([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])single[ -]use([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])ready([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])reset([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])update(d|ing)([^a-zA-Z0-9]|$).*", # not update, need action
        ".*(^|[^a-zA-Z0-9])verif(y|ied|ication)([^a-zA-Z0-9]|$).*"
      ]
    )
  ) {
    if not header :comparator "i;unicode-casemap" :regex "subject" [
      ".*(^|[^a-zA-Z0-9])statement([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])tax(ed|able|ation)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])welcome([^a-zA-Z0-9]|$).*"
    ] {
      expire "day" "${non_critical_alerts_expiry_days}";
      fileinto "expiring";
    }
    fileinto "Alerts";
    if string :comparator "i;ascii-numeric" :value "ge" "${received_julian_day}" "${migration_julian_day}" {
      fileinto "inbox";
    }
    stop;
  }
}

#              ▗     ▘▜ 
#  ▛▌▀▌▛▌█▌▛▘  ▜▘▛▘▀▌▌▐ 
#  ▙▌█▌▙▌▙▖▌   ▐▖▌ █▌▌▐▖
#  ▌   ▌                

if not anyof(
  header :comparator "i;unicode-casemap" :regex "subject" [
    # <copy LABEL DECORATION - conversations>
    ".*fw: .*",
    ".*fwd: .*",
    ".*re: .*"
    # </copy LABEL DECORATION - conversations>
  ],
  header :list [
    "from",
    "to",
    "X-Original-To"] [":addrbook:personal?label=Family", ":addrbook:personal?label=Friends", ":addrbook:personal?label.ends-with=Politics"],
  header :comparator "i;unicode-casemap" :regex "subject" [
    # <copy LABEL DECORATION - licence key checks>
    ".*(^|[^a-zA-Z0-9])download([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])licen(c|s)e([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])link([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])product ?key([^a-zA-Z0-9]|$).*",
    # </copy LABEL DECORATION - licence key checks>
    ".*(^|[^a-zA-Z0-9])tax(able|ed|ation)?([^a-zA-Z0-9]|$).*",
	".*ulwark.*"
  ]) {

  # PAPER TRAIL - auto archive by 
      
  # PAPER TRAIL - statements

  if header :comparator "i;unicode-casemap" :regex ["Subject"] [
    ".*(^|[^a-zA-Z0-9])bill([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])report.*securities([^a-zA-Z0-9]|$).*", # Fidelity securites loan statements
    ".*(^|[^a-zA-Z0-9])e?statement([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])your.*transaction history([^a-zA-Z0-9]|$).*"
    ] {

    fileinto "statements";

    expire "day" "${paper_trail_expiry_relative_days}";
    fileinto "expiring";
    if header :list "from" ":addrbook:personal" {
      addflag "\\Seen";
    }
    fileinto "Paper Trail";
    stop;
  } elsif allof (

    # PAPER TRAIL - returns

    header :comparator "i;unicode-casemap" :regex "subject" [
      ".*(^|[^a-zA-Z0-9])return([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])refund([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])rma([^a-zA-Z0-9]|$).*"
    ],
    header :comparator "i;unicode-casemap" :regex "subject" [
      ".*(^|[^a-zA-Z0-9])authoriz(e|ed|ing|ation)([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])by mail([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])confirm(ed|ing|ation)([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])complete(d|ing)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])label([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])notif(y|ied|ing|ication)([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])parcel([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])process(ed|ing)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])order([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])rma([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])receive?(d|ing)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])request([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])your?([^a-zA-Z0-9]|$).*"
    ]
  ) {
    fileinto "shopping";
    fileinto "returns";

    expire "day" "${paper_trail_expiry_relative_days}";
    fileinto "expiring";
    if header :list "from" ":addrbook:personal" {
      addflag "\\Seen";
    }
    fileinto "Paper Trail";
    stop;
  } elsif anyof(

    # PAPER TRAIL - tracking
    header :comparator "i;unicode-casemap" :is "from" "USPSInformeddelivery@email.informeddelivery.usps.com",
    header :comparator "i;unicode-casemap" :regex "subject" [
      ".*(^|[^a-zA-Z0-9])arrived:([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])delivered:([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])dispatched:([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])pick(- )?up confirm(ed|ation)([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])shipped:([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])shipping.*confirm(ed|ation)([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])shipping.*accept(ed|ation)([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])your shipment([^a-zA-Z0-9]|$).*"
    ],

    allof (
      header :comparator "i;unicode-casemap" :regex "subject" [
        ".*(^|[^a-zA-Z0-9])delivery([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])driver([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])gear([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])item([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])label([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])order([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])package([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])payment([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])forwarding([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])shipment([^a-zA-Z0-9]|$).*"
      ],
      header :comparator "i;unicode-casemap" :regex "subject" [
        ".*(^|[^a-zA-Z0-9])arriv(e|ed|ing)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])chang(e|ed|ing)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])cancel(led|ling)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])coming (soon|today|tomorrow)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])complet(e|ed|ing)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])clear(ed)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])deliver(y|ed|ing)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])dispatch(ed|ing)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])get ready([^a-zA-Z0-9]|$).*", # UPS - "get ready for your package"
        ".*(^|[^a-zA-Z0-9])making moves([^a-zA-Z0-9]|$).*", # Peak Design
        ".*(^|[^a-zA-Z0-9])notif(y|ied|ication)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])on (the|its) way([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])out for([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])prepar(e|ed|ing)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])print(ed|ing)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])process(ed|ing)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])(re)?schedul(ed|ing)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])sent([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])shipp(ed|ing)([^a-zA-Z0-9]|$).*", # not shipment
        ".*(^|[^a-zA-Z0-9])sign(ed)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])status([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])track(ed|ing)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])updat(e|ed|ing)([^a-zA-Z0-9]|$).*"
      ]
  )) {

    fileinto "tracking";

    expire "day" "${paper_trail_expiry_relative_days}";
    fileinto "expiring";
    if header :list "from" ":addrbook:personal" {
      addflag "\\Seen";
    } 
    fileinto "Paper Trail";
    stop;
  } elsif anyof(

    # PAPER TRAIL - transactions
    # NB don't put "you" and "your" in each limb, too broad
    # (e.g., "your flight to SF is waiting for you")

    header :comparator "i;unicode-casemap" :regex "Subject" [
          # Venmo transactions, without adding overly broad "you(r)" to main limbs
          ".*(^|[^a-zA-Z0-9])requests.*[0-9]{1,}\\.[0-9]{2,2}.*",
          # Schwab etrade confirmations
          ".*(^|[^a-zA-Z0-9])econfirms([^a-zA-Z0-9]|$).*"
    ],

    allof(
      # Kraken transactions, without adding overly broad "you(r)" to main limbs
      header :comparator "i;unicode-casemap" :regex "Subject" [
        ".*(^|[^a-zA-Z0-9])you([^a-zA-Z0-9]|$).*"
      ],
      anyof(
          header :comparator "i;unicode-casemap" :regex "Subject" [
          ".*(^|[^a-zA-Z0-9])bought([^a-zA-Z0-9]|$).*",
          ".*(^|[^a-zA-Z0-9])converted([^a-zA-Z0-9]|$).*",
          ".*(^|[^a-zA-Z0-9])paid([^a-zA-Z0-9]|$).*",
          ".*(^|[^a-zA-Z0-9])(sent|received).*(money|gift|$).*",
          ".*(^|[^a-zA-Z0-9])sold([^a-zA-Z0-9]|$).*" 
          ]
      )
    ),
    allof(
      header :comparator "i;unicode-casemap" :regex "Subject" [
        ".*(^|[^a-zA-Z0-9])credit([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])debit([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])deposit([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])eft([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])electronic funds transfer([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])expense([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])listing([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])(auto)?pay(ment)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])purchase([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])rent([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])request([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])trade([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])transaction([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])transfer([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])withdrawal([^a-zA-Z0-9]|$).*"
      ],
      header :comparator "i;unicode-casemap" :regex "Subject" [
        ".*(^|[^a-zA-Z0-9])activity([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])approve(d|al)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])authorized([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])bought([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])coming up([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])completed?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])confirm(ed|ation)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])execut(ed|ing)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])for.*2[0-9]{3}([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])initiat(ed|ing)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])paid([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])pick(ing)?[ -]?up([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])process(ed|ing)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])receiv(ed|ing)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])sent([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])set([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])started([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])successful([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])thank(s|you) for([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])transfer(red|ring)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])working([^a-zA-Z0-9]|$).*"
      ]
    )
  ) {

    fileinto "transactions";
    # expire "day" "${paper_trail_expiry_relative_days}";
    # fileinto "expiring";

    if header :list "from" ":addrbook:personal" {
      addflag "\\Seen";
    }
    fileinto "Paper Trail";
    stop;
  } elsif anyof(

    # PAPER TRAIL - receipts
    # Comes last as catch all for more specific paper trail states above.

    # specific cases
    header :comparator "i;unicode-casemap" :regex "Subject" [
      # Reverb
      ".*(^|[^a-zA-Z0-9])has sold([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])thanks for picking up([^a-zA-Z0-9]|$).*",
      # REI - picking up gear in person
      ".*(^|[^a-zA-Z0-9])thanks for picking up([^a-zA-Z0-9]|$).*",
      # Lyft
      ".*(^|[^a-zA-Z0-9])your ride with([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])your Lyft bike ride([^a-zA-Z0-9]|$).*",
      # Paypal: "seller: $xxx.xx USD"
      ".*:.{1,2}[0-9]{1,}\\.[0-9]{2,2}.*",
      # Storage - these are sent every month
      ".*(^|[^a-zA-Z0-9])safestor policy (auto-)?renewal([^a-zA-Z0-9]|$).*",
      #Uber
      ".*(^|[^a-zA-Z0-9])your.*(morning|afternoon|evening).*trip([^a-zA-Z0-9]|$).*"
    ],

    # general
    header :comparator "i;unicode-casemap" :regex "Subject" [
      ".*invoice.*",
      ".*(^|[^a-zA-Z0-9])order #? ?[0-9]+([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])ordered:([^a-zA-Z0-9]|$).*",
      ".*receipt.*"
    ],

    allof (
      header :comparator "i;unicode-casemap" :matches [
        "Subject",
        "From",
        "To"
      ] [
        "*charge*",
        "*checkout*",
        "*credit*",
        "*domain*",
        "*earnings*",
        "*forwarding request*",
        "*item*",
        "*order*",
        "*payment*",
        "*purchase*",
        "*rental*",
        "*sale*",
        "*shopping*",
        "*subscription*",
        "*ticket*",
        "*ultimate rewards*"
      ],

      header :comparator "i;unicode-casemap" :regex "Subject" [
        ".*(^|[^a-zA-Z0-9])accepted([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])complet(e|ed|tion)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])confirm(ed|ation)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])details([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])from([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])issued([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])on the way([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])plac(e|ed|ing)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])receiv(e|ed|ing)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])refund(ed)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])sale([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])sold([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])submit(ted)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])succe(ss|eded)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])summary([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])thank(s|you) for([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])your([^a-zA-Z0-9]|$).*"
      ])
    ) {

    fileinto "receipts";

    if header :comparator "i;unicode-casemap" :matches "Subject" [
      "*invoice*",
      "*order*",
      "*purchase*",
      "*sale*",
      "*shopping*"
    ] {
      fileinto "shopping";
    }

    # expire "day" "${paper_trail_expiry_relative_days}";
    # fileinto "expiring";
    if header :list "from" ":addrbook:personal" {
      addflag "\\Seen";
    }
    fileinto "Paper Trail";
    stop;
  }
}

#     ▗   ▘    ▐▘  ▜  ▌       
# ▛▌▌▌▜▘  ▌▛▌  ▜▘▛▌▐ ▛▌█▌▛▘▛▘ 
# ▙▌▙▌▐▖  ▌▌▌  ▐ ▙▌▐▖▙▌▙▖▌ ▄▌ 
# ▌                           
#
# I kind of hate labels, so instead, put things that are non-newsletters into folders before we get to there.  I don't wanna see these in my inbox.

# FOLDERS - Scans; catches all the emails with attachments from scanning stuff at my library
if header :comparator "i;unicode-casemap" :is "from" "my-library@library.org" {
  fileinto "Scans";
  stop;
}
# FOLDERS - donations
if header :comparator "i;unicode-casemap" :regex [
    "from",
    "X-Simplelogin-Original-From",
    "subject"
  ] [
    ".*(^|[^a-zA-Z0-9])donat(e|ion)?([^a-zA-Z0-9]|$).*"
  ] {
  fileinto "Money/Donations";
  stop;
}
# FOLDERS - Health
 # todo: this is catching newsletters...exclude that at the top of this section.
if anyof (
	header :comparator "i;unicode-casemap" :regex [
    "from",
    "X-Simplelogin-Original-From",
    "subject"
    ] [
      ".*my ?health.*",
      ".*health ?care.*",
      ".*medic(ine|al).*",
	  ".*phys(io|ical )therapy.*",
	  ".*psych.*",
    ".*vaccin.*",
    ".*aetna.*"  
]) {
  fileinto "Personal/Health";
  stop;
}
# FOLDERS - school stuff
if allof(
	# filters here
)) {
  fileinto "School";
  stop;
}
# FOLDERS - Volunteering
if anyof (
	# filters here
) {
    fileinto "Personal/Volunteering";
}

# FOLDERS - Shops
if header :comparator "i;unicode-casemap" :contains "Message-Id" ["shopify"]
{
  # some shops don't have an email address, but we can catch them with this header instead...
  # todo: expire these.
  fileinto "Newsletters/Shops";
}

# FOLDERS - Work
if anyof (
    address :all :comparator "i;unicode-casemap" :contains "From" ["linkedin"]) {
  fileinto "Work";
  stop;
}

# FOLDERS - Code stuff from code places
if anyof (
    address :all :comparator "i;unicode-casemap" :contains "From" ["github", "hackerrank"]) {
  fileinto "Work/Code";
	stop;
}

# FOLDERS - job listing emails
if anyof (
    header :comparator "i;unicode-casemap" :contains "From" ["job-listings@stuff.com"]
) {
  fileinto "Work/Jobs";
	stop;
}


#  ▗ ▌     ▐▘     ▌
#  ▜▘▛▌█▌  ▜▘█▌█▌▛▌
#  ▐▖▌▌▙▖  ▐ ▙▖▙▖▙▌
#                  
# I modified my groups so that anything that goes in here starts with "Newsletters"; there are too many newsletters to just pile them in one folder, 
# so I have them subsorted after hitting the first filter check.

# THE FEED - contact groups indicator
if header :list ["from", "to", "X-Original-To"] ":addrbook:personal?label.starts-with=Newsletters"
{
	# THE FEED - politics
  if header :list ["from", "to", "X-Original-To"] ":addrbook:personal?label.ends-with=Politics" {
	if header :comparator "i;unicode-casemap" :regex "subject" ".*arn.*points" {
	  # Should toss out YouGov "earn 344345345 points" emails
      fileinto "Trash";
      stop;
    } elsif anyof(
		header :list ["from", "to", "X-Original-To", "Cc", "Bcc"] ":addrbook:personal?label.ends-with=Local",
		header :comparator "i;unicode-casemap" :contains ["Subject", "List-Subscribe", "List-Archive"] ["other words"]
	) {
      fileinto "Newsletters/Politics/Local";
    } elsif header :list ["from", "to", "X-Original-To"] ":addrbook:personal?label.ends-with=Advocacy" {
      fileinto "Newsletters/Politics/Advocacy";
    } elsif header :list ["from", "to", "X-Original-To"] ":addrbook:personal?label.ends-with=News" {
	  fileinto "Newsletters/Politics/News";
    }
    else {
	 fileinto "Newsletters/Politics";
    }
  } 
  # THE FEED - crafts
  elsif header :list ["from", "to", "X-Original-To"] ":addrbook:personal?label.ends-with=Crafts" {
	fileinto "Newsletters/Crafts";
  }
  # THE FEED - substack
  elsif header :list ["from", "to", "X-Original-To"] ":addrbook:personal?label.ends-with=Substack" {
	fileinto "Newsletters/Substack";
  }
  # THE FEED - charities
  elsif header :list ["from", "to", "X-Original-To"] ":addrbook:personal?label.ends-with=Charities" {
	fileinto "Newsletters/Charities";
  }
  # THE FEED - shops
  elsif header :list ["from", "to", "X-Original-To"] ":addrbook:personal?label.ends-with=Shops" {
	fileinto "Newsletters/Shops";
  }
  # THE FEED - subscriptions
  elsif header :list ["from", "to", "X-Original-To", "Cc", "Bcc"] ":addrbook:personal?label.ends-with=Subscriptions"
  {
    fileinto "Newsletters/Subscriptions";
  }
  # THE FEED - music
  elsif header :list ["from", "to", "X-Original-To", "Cc", "Bcc"] ":addrbook:personal?label.ends-with=Music" {
    fileinto "Newsletters/Music";
  }

  # THE FEED - patreon
  elsif header :comparator "i;unicode-casemap" :regex [
    "from",
    "X-Simplelogin-Original-From",
    "subject"
    ] [
      ".*patreon.*"
  ]  {
    fileinto "Newsletters/Patreon";
  }
  else {
    fileinto "Newsletters";
  }
  # I don't need this, but leaving itt here for now.
  if header :comparator "i;unicode-casemap" :matches "from" "*hello@deals.going.com*" {
    # Going.com deals no good after a week
    expire "day" "${non_critical_alerts_expiry_days}";
  } else {
    expire "day" "${newsletter_expiry_relative_days}";
  }
  fileinto "expiring";
  stop;
}

#         ▌       ▌   ▘  
#  ▛▌█▌█▌▛▌▛▘  ▀▌▛▌▛▛▌▌▛▌
#  ▌▌▙▖▙▖▙▌▄▌  █▌▙▌▌▌▌▌▌▌
#                        

# SCREENER - old addresses
if allof(
  header :list [
    "bcc",
    "cc",
    "to",
    "X-Original-To",
    "X-Simplelogin-Envelope-To"
  ] ":addrbook:personal?label=Old Addresses",
  not header :list [
    "bcc",
    "cc",
    "to",
    "X-Original-To",
    "X-Simplelogin-Envelope-To"
  ] ":addrbook:personal?label=Migration Exceptions",
  string :comparator "i;ascii-numeric" :value "ge" "${received_julian_day}" "${migration_julian_day}"
) {
  fileinto "changeme";
  fileinto "inbox";
  stop;
}

# SCREENER - needs an alias; I moved this down here because I kind of don't care about things needing an alias if they got stopped earlier...
# THAT BEING SAID: I've already done a pretty solid job of de-googling my email addresses, so if you haven't, I'd move this to the top of the sieve.
if not address :contains "To" ["passmail.net", "passmail.com", "passfwd.com", "passinbox.com"] {
	fileinto "needs-alias";
}

# SCREENER - final fallthrough
if allof(
  string :comparator "i;ascii-numeric" :value "ge" "${received_julian_day}" "${migration_julian_day}",
  not header :list ["from", "to"] ":addrbook:personal") {
  fileinto "needs-filter";
  stop;
}

#############
## Default ##
#############
else {
  fileinto "needs-filter";
stop;
}
