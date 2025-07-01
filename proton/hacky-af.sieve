require ["include", "environment", "variables", "relational", "comparator-i;ascii-numeric", "spamtest"];
require ["fileinto", "imap4flags", "extlists", "regex"];

# Generated: Do not run this script on spam messages
if allof (environment :matches "vnd.proton.spam-threshold" "*", spamtest :value "ge" :comparator "i;ascii-numeric" "${1}") {
    return;
}

# File anything from people in Friends or Family into Correspondence and then stop.
if anyof (
    header :list "from" ":addrbook:personal?label=Friends",
    header :list "from" ":addrbook:personal?label=Family",
    header :contains "In-Reply-To" "@{YOUR-DOMAIN}.com"
) {    
	fileinto "Personal/Correspondence";
	return;
}

##########################
##    ▌ ▌  ▜   ▌   ▜    ##
## ▀▌▛▌▛▌  ▐ ▀▌▛▌█▌▐ ▛▘ ##
## █▌▙▌▙▌  ▐▖█▌▙▌▙▖▐▖▄▌ ##
##########################

##########################
## Label NGP Van Emails ##
##########################
if header :contains "list-unsubscribe" ["ngpvan", "actionkit"] {
  # Emails that come from being on political email lists, since you can never escape them...
	fileinto "partisans-list";
}
if address :is "To" ["{OLD_GMAIL_ONE}", "{OLD_GMAIL_TWO}"] {
  # Label all emails being forwarded from Gmail or other accounts so can later unsub or change email address at source, then stop.  Strangler pattern.
  fileinto "changeme";
  return;
}
if not address :contains "To" ["passmail.net", "passmail.com", "passfwd.com", "passinbox.com"] {
  # Label all emails not using an alias so can later unsub or convert to alias
	fileinto "needs-alias";
}
#################################
##     ▗   ▘    ▐▘  ▜  ▌       ##
## ▛▌▌▌▜▘  ▌▛▌  ▜▘▛▌▐ ▛▌█▌▛▘▛▘ ##
## ▙▌▙▌▐▖  ▌▌▌  ▐ ▙▌▐▖▙▌▙▖▌ ▄▌ ##
## ▌                           ##
#################################
# Highly me-opinionated sorting mechanism.  Works for me, for now.  YMMV.  Steal what you want.
# Most of the below IFs stop after putting email in a folder.  Order if's by precedent if some things might match multiple filters (rare, but happens)
# TODO: convert to using contact groups so we can stop appending email aliases/sender addresses to these filters

############
## Orders ##
############
if allof (
    # hackiest of all regexes bc am lazy: look for emails where title contains language likely to be order-related
	anyof(header :regex "Subject" ".*[Ii]nvoice.*|.*[Yy]our .* [Oo]rder.*|.*[Oo]rder #?[0-9]*.*|.*[Oo]rder [Cc]onfirmation.*|.*[Rr]eceipt.*|.*[Ss]hip[sp][ei]?[nd]?[g]?.*|.*[Pp]ackage.*|.*[Dd]eliver[ey][d]?.*|.*[Bb]ooking.*|.*[Pp]urchase.*",
    address :all :comparator "i;unicode-casemap" :contains "From" ["{KNOWN_ORDERING_ADDRESS}"],
	address :all :comparator "i;unicode-casemap" :is ["To", "Cc", "Bcc"] ["{EMAIL_ADDY_USED_ONLY_FOR_ORDERING}"]
    )) {
  	fileinto "Money/Orders";
	return;
}
###############
## Charities ##
###############
if anyof (
	header :comparator "i;unicode-casemap" :contains "Subject" ["donation receipt"], 
    address :is "From" ["{KNOWN_DONATION_SEND_EMAIL_ADDY"],
    address :all :comparator "i;unicode-casemap" :contains "From"["{CHARITY_ONE}", "{CHARITY_TWO}", "{ETC}"],
	address :all :contains "To" ["{ADDY_USED_FOR_DONATIONS}"]
) {
  	fileinto "Money/Charities";
	return;
}
##################
## School Stuff ##
##################
if allof (
    address :all :comparator "i;unicode-casemap" :contains ["To", "Cc", "Bcc"] ["{MY_SCHOOL_ADDRESS}"],
    address :all :comparator "i;unicode-casemap" :contains "From" ["{SCHOOL_ADDRESS_KEYWORDS}"]
) {
    fileinto "School";
	return;
}
##############
## Politics ##
## National ##
##############
if anyof (
    header :comparator "i;unicode-casemap" :contains "Subject" "congress.gov", 
    address :all :comparator "i;unicode-casemap" :contains "From" ["loc@service.govdelivery.com", "yougov.com", "{OTHER_KEYWORDS}"]
    ) {
if header :contains "Subject" "Earn 250 points" {
    # Ignore yougov's "EARN X POINTS" emails; this is fragile because they sometimes change the number/title...meh.  Change to regex maybe?  Again, meh.
	fileinto "Trash";
} else {
    fileinto "Newsletters/Politics";
}
	return;
}
##############
## Politics ##
##   Local  ##
##############
if anyof (
    header :comparator "i;unicode-casemap" :contains "Subject" "{LOCAL_SUBJECT}", 
    header :comparator "i;unicode-casemap" :contains "List-Subscribe" ["{LOCAL_LIST_SUB_HEADER}"],
	header :comparator "i;unicode-casemap" :contains "List-Archive" ["{LOCAL_LIST_ARCHIVE_HEADER}"],
    address :all :comparator "i;unicode-casemap" :contains "From" ["{LOCAL}", "{POLITICS}", "{KEYWORDS}"],
	address :all :comparator "i;unicode-casemap" :is ["To", "Cc", "Bcc"] ["{ALIAS_USED_FOR_POLITICS}"]
) {
    fileinto "Newsletters/Politics/local";
	return;
}
##############
## Politics ##
##   News   ##
##############
if anyof (
    address :all :comparator "i;unicode-casemap" :contains "From" ["{NEWSPAPER_ONE}", "{NEWSPAPER_TWO}", "{ETC}"]
) {
    fileinto "Newsletters/Politics/news";
	return;
}
##############
## Politics ##
## Advocacy ##
##############
if anyof (
    address :all :comparator "i;unicode-casemap" :contains "From" ["{ADVOCACY_GROUP_EMAIL_KEYWORDS}"],
	 address :all :comparator "i;unicode-casemap" :is ["To", "Cc", "Bcc"] ["{ADVOCACY_GROUP_ALIAS_USED"]
) {
    fileinto "Newsletters/Politics/advocacy";
	return;
}
##################
## Volunteering ##
##################
if anyof (
	header :comparator "i;unicode-casemap" :contains "Subject" "{VOLUNTEERING_SUBJECT}",
    address :all :comparator "i;unicode-casemap" :contains "From" ["{VOLUNTEERING_KEYWORD}"],
    header :comparator "i;unicode-casemap" :contains "X-Simplelogin-Original-List-Unsubscribe" ["{VOLUNTEER_LIST_UNSUB_HEADER"]
) {
    fileinto "Volunteering";
	return;
}
###################
## Subscriptions ##
###################
if anyof (
    address :all :comparator "i;unicode-casemap" :is ["To", "Cc", "Bcc"] ["{ALIAS_USED_FOR_SUBS}"], 
    address :all :comparator "i;unicode-casemap" :contains "From" ["{SUBSCRIPTION_ALIASES}"]
) {
  # I use this filter for things I pay to subscribe to, as recurring payments for services/items
    fileinto "Money/Subscription";
	return;
}
############
## Health ##
############
if anyof (
    header :comparator "i;unicode-casemap" :contains "Subject" ["{HEALTH_KEYWORDS}"],
    address :all :comparator "i;unicode-casemap" :contains "From" ["{INSURANCE_PROVIDER_EMAIL_KEYWORD}", "{ETC}"],
	address :all :comparator "i;unicode-casemap" :contains "To" ["{ALIAS_USED_FOR_HEALTHCARE}"]
    ) {
	fileinto "Money/Health";
	return;
}
###################
## Housing Stuff ##
###################
if anyof (
    address :all :comparator "i;unicode-casemap" :contains "From" ["{ISP_EMAIL_KEYWORD}", "{UTILITIES_EMAIL_KEYWORD}", "{ETC}"], 
    address :all :comparator "i;unicode-casemap" :is ["To", "Cc", "Bcc"] ["{ALIAS_USED_FOR_HOUSING_STUFF}"],
	header :comparator "i;unicode-casemap" :contains "Subject" ["{HOUSING_SUBJECT}"]
) {
    fileinto "Housing";
	return;
}
#############
## Patreon ##
#############
if allof (
    address :all :comparator "i;unicode-casemap" :is ["To", "Cc", "Bcc"] "{ADDRESS_USED_FOR_PATREON}"
) {
    fileinto "Money/Patreon";
	return;
}
###########
## Money ##
###########
if anyof (
    address :all :comparator "i;unicode-casemap" :contains "From" ["paypal", "venmo", "gofundme", "{ETC}"],
	address :all :comparator "i;unicode-casemap" :is ["To", "Cc", "Bcc"] ["{ALIAS_USED_FOR_MONEY_STUFF}"],
    header :comparator "i;unicode-casemap" :contains "Subject" ["{MONEY_KEYWORDS"],
   	header :comparator "i;unicode-casemap" :contains "Reply-to" ["{MONEY_REPLY_TO_KEYWORD}"]
) {
    fileinto "Money";
	return;
}
#################
## Newsletters ##
#################
if anyof (
    address :all :comparator "i;unicode-casemap" :contains "From" ["{NEWSLETTER_EMAIL_KEYWORDS}"],
    header :comparator "i;unicode-casemap" :contains "Reply-to" ["{NEWSLETTER_REPLY_TO"],
    address :all :comparator "i;unicode-casemap" :is ["To", "Cc", "Bcc"] ["{ALIAS_FOR_NEWSLETTER}"]
    ) {
  fileinto "Newsletters";
  if address :all :comparator "i;unicode-casemap" :is ["To", "Cc", "Bcc"] ["{SUBCATEGORIZE_EMAIL_ALIAS}"] {
	## more newsletter subcategories; needs consolidation at some point?
	fileinto "{subcategory}";
  }
	return;
}
###################
## Google Alerts ##
###################
if anyof (
    address :all :comparator "i;unicode-casemap" :contains "From" ["googlealerts-noreply@google.com", "noreply-location-sharing@google.com"]
) {
  # todo: consol with above
    fileinto "Newsletters/gAlerts";
	return;
}

#############
## Transit ##
#############
if anyof (
    address :all :comparator "i;unicode-casemap" :contains "From" ["{TRANSIT_EMAIL_KEYWORDS}"]
) {
  # todo: consol with above
    fileinto "Newsletters/Transit";
	return;
}
###########
## Shops ##
###########
if anyof (
    address :all :comparator "i;unicode-casemap" :contains "From" ["{SHOP_EMAIL_KEYWORDS}"],
	address :all :comparator "i;unicode-casemap" :contains "To" ["{ALIAS_USED_FOR_SHOPS}"], 
    header :comparator "i;unicode-casemap" :contains "Reply-to" ["{SHOP_REPLY_TO_HEADER}"],
    header :comparator "i;unicode-casemap" :contains "Message-Id" ["shopify"]
) {
    fileinto "Newsletters/Shops";
	return;
}
############
## Crafts ##
############
if anyof (
	header :comparator "i;unicode-casemap" :contains "List-Subscribe" ["{CRAFT_SUB_HEADER}"],
    address :all :comparator "i;unicode-casemap" :contains "From" ["{CRAFT_EMAIL_KEYWORDS}"]) {
    fileinto "Newsletters/Crafts";
	return;
}
###########
## Music ##
###########
if anyof (
    address :all :comparator "i;unicode-casemap" :contains "From" ["{BAND_ONE}", "{BAND_TWO}", "{VENUE_ONE}", "Bandcamp", "newsletter@email.ticketmaster.com", "emporium@engage.ticketmaster"]) {
    fileinto "Newsletters/Music";
	return;
}
##########
## Work ##
##########
if anyof (
    address :all :comparator "i;unicode-casemap" :contains "From" ["linkedin", "{WORK_EMAIL_KEYWORD}"]) {
  fileinto "Work";
	return;
}
##########
## Code ##
##########
if anyof (
    address :all :comparator "i;unicode-casemap" :contains "From" ["github", "{CODE_EMAIL_KEYWORD}"]) {
  fileinto "Work/Code";
	return;
}
##################
## Job Listings ##
##################
if anyof (
    header :comparator "i;unicode-casemap" :contains "From" ["{JOB_BOARD_EMAIL_KEYWORD}"]
) {
  fileinto "Work/Jobs";
	return;
}

######################
## Delete the Trash ##
######################
if anyof (
    header :comparator "i;unicode-casemap" :contains "From" ["{TRASH_EMAIL_KEYWORD"]) {
	discard;  # permanently delete the email; use caution
	return;
}
################
## Catch-alls ##
################
##############
## Substack ##
##############
if anyof (
    address :all :comparator "i;unicode-casemap" :contains "From" ["substack"]
) {
    fileinto "Newsletters/Substack";
	return;
}
#############
## Default ##
#############
else {
  # anything that wasn't caught by a filter above needs to get labeled so can later add it to filter/contact group/whatever
	fileinto "needs-filter";
  	return;
}
