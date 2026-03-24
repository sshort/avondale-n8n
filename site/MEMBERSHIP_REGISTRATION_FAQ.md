# Membership Registration FAQ

This FAQ covers common end-user technical problems when registering for membership on ClubSpark and paying through Stripe.

Support contact:
- `members.avondaleltc@gmail.com`

Club website:
- `https://clubspark.lta.org.uk/AvondaleTennisClub`

## Before You Start

For the smoothest registration and payment flow:
- use a normal desktop or mobile browser, not an in-app browser from Gmail, Facebook, or WhatsApp
- avoid VPNs, corporate web filters, and privacy tools that block cookies or payment pages
- keep only one registration tab open
- complete the registration in one sitting without refreshing the page

Recommended browsers:
- Chrome
- Edge
- Safari
- Firefox

## ClubSpark Website Problems

### The ClubSpark page will not load properly

Try this first:
- turn off any VPN
- disable ad blockers or privacy extensions for ClubSpark
- retry on mobile data instead of filtered Wi-Fi
- refresh once, then try a different browser

Possible causes:
- VPN or network filtering
- blocked scripts or cookies
- temporary browser cache corruption
- an old browser version

### I keep getting logged out or sent back to the start

This is usually a session or cookie problem.

Try:
- close extra ClubSpark tabs
- clear cookies for `clubspark.lta.org.uk`
- turn off strict tracking protection for the site
- do not use private/incognito mode for payment

### The website says my details are invalid

ClubSpark profile data can block registration if key fields are missing or malformed.

Check:
- first name and last name are present
- date of birth is correct
- email address is valid
- postcode is valid
- address has at least one address line and a postcode

Common profile issues:
- missing surname
- junior account using the wrong date of birth
- family member details entered under the wrong person
- incomplete address
- old email address still attached to the profile

### I cannot see the membership package I expected

Possible reasons:
- you are signed in as the wrong person
- the package is age-restricted
- the member profile date of birth is wrong
- the package is only shown for eligible members
- the package has already been registered

If a junior or family package is missing, check the member profile before retrying.

### I clicked register and the page seemed to do nothing

Possible causes:
- JavaScript blocked by browser extension
- slow network
- stale page session
- background popup or authentication window blocked

Try:
- wait 10 to 20 seconds before clicking again
- do not double-click the button
- reload the registration page once
- retry in another browser if needed

## Stripe Payment Problems

### The Stripe payment page does not appear

Possible causes:
- popup blocker
- blocked third-party cookies
- VPN or privacy extension interfering with Stripe
- browser session timed out

Try:
- disable blockers temporarily
- turn off VPN
- use a normal browser window
- retry in Chrome, Edge, or Safari

### The bank verification or 3D Secure step fails

This is one of the most common technical issues.

Try:
- avoid in-app browsers
- use the bank app if prompted
- keep the payment tab open while approving in the bank app
- return to the original browser tab after approval
- retry on a different device if the challenge page is blank or frozen

Common causes:
- mobile banking app opens but does not return cleanly
- embedded browser cannot complete the redirect
- strict privacy settings block the challenge window
- the bank challenge times out

### The payment page hangs or spins forever

Do not keep retrying immediately.

First check:
- whether your bank shows a pending payment
- whether you received a confirmation email
- whether ClubSpark now shows the membership

If there is any sign the payment may have gone through, stop and ask support to check before trying again.

### Apple Pay or Google Pay is not showing

That does not always mean something is broken.

Wallet options may be hidden if:
- the device/browser combination is unsupported
- the wallet is not set up on that device
- the page is opened in an embedded browser
- Stripe decides only card entry should be shown for that session

If wallet payment is not offered, use standard card payment in a supported browser.

### My card is valid but Stripe declines it

Possible causes:
- bank fraud checks
- name or billing details mismatch
- expired card
- card not enabled for online payments
- temporary bank-side failure

Try:
- re-enter the card carefully
- check the billing postcode
- try another card
- check with your bank

### I closed the page during payment

Do not assume it failed.

Check:
- bank app or statement
- confirmation email
- ClubSpark membership status

Refreshing or retrying too quickly can create duplicate attempts.

## Network and Device Issues

### Does a VPN matter?

Yes, sometimes.

A VPN can interfere with:
- ClubSpark page loading
- Stripe fraud checks
- 3D Secure redirects
- cookie and session handling

If payment or login behaves strangely, disable the VPN and retry.

### Does corporate, school, or guest Wi-Fi matter?

Yes.

Filtered networks can block:
- Stripe scripts
- bank verification pages
- redirects between payment and ClubSpark

If possible, retry on:
- home broadband
- mobile data

### Does browser privacy mode matter?

Yes.

Incognito/private mode and aggressive anti-tracking settings can break:
- login sessions
- payment hand-off
- 3D Secure return flow

Use a normal browser window if possible.

## Duplicate or Confusing Results

### I am not sure whether the registration worked

Check these in order:
1. Did the bank show a charge or pending authorisation?
2. Did you receive a confirmation email?
3. Does ClubSpark now show the membership?

If the answer is unclear, do not keep retrying.

### I think I may have paid twice

This often happens after:
- refreshing the payment page
- opening a second tab
- retrying while the first attempt was still pending

Send support:
- member name
- membership package
- approximate payment time
- amount
- screenshot or statement extract if available

## What To Send Support

If you need help, send:
- full member name
- email address used on ClubSpark
- membership package
- device and browser used
- whether a VPN was on
- approximate time of the problem
- screenshot of the error if possible

For payment issues also include:
- whether Stripe showed success, failure, or hung
- whether the bank shows pending or completed payment
- whether you retried
