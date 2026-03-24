# Membership Registration Support Runbook

This is the internal support runbook for troubleshooting member-facing problems with ClubSpark registration and Stripe payments.

Related docs:
- [MEMBERSHIP_REGISTRATION_FAQ.md](./MEMBERSHIP_REGISTRATION_FAQ.md)
- [MEMBERSHIP_REGISTRATION_FAQ_PUBLIC.md](./MEMBERSHIP_REGISTRATION_FAQ_PUBLIC.md)

Support mailbox:
- `members.avondaleltc@gmail.com`

Primary member journey:
1. Member signs into ClubSpark.
2. Member selects a membership package.
3. Stripe takes payment.
4. ClubSpark updates membership state.
5. Local automation captures signup and downstream admin data.

## Quick Triage

Ask these first:
1. What exact package was the member trying to buy?
2. Which person was signed into ClubSpark?
3. Did Stripe show success, failure, or hang?
4. Does the bank show pending or completed payment?
5. Did the member receive a confirmation email?
6. Is a VPN, corporate network, ad blocker, or privacy browser involved?

## Common Technical Causes

### VPN or filtered network

Symptoms:
- ClubSpark pages partly load
- Stripe payment page does not open
- 3D Secure challenge fails or loops

Advice:
- ask the member to turn off VPN
- retry on home broadband or mobile data
- avoid school/corporate guest networks

### Embedded or in-app browser

Symptoms:
- payment page fails to return properly
- bank app approval completes but ClubSpark does not recover
- Apple Pay / Google Pay does not appear

Advice:
- open the site directly in Safari, Chrome, Edge, or Firefox
- avoid Gmail, Facebook, Instagram, WhatsApp, or other in-app browsers

### Cookies, popups, or privacy protection blocked

Symptoms:
- ClubSpark login loops
- session resets
- Stripe or bank challenge never appears
- user is sent back to the start

Advice:
- allow popups
- disable strict privacy tools for the site
- clear cookies for `clubspark.lta.org.uk`
- retry in a normal browser window

### Invalid or incomplete profile data

Symptoms:
- expected package missing
- registration blocked
- wrong eligibility

Check:
- first name and surname present
- date of birth correct
- email address valid
- address has at least one line and a postcode
- correct person is selected in family accounts

### Duplicate attempts

Symptoms:
- member retried because page looked stuck
- multiple pending or completed bank entries
- multiple emails or inconsistent ClubSpark state

Advice:
- stop further retries
- confirm whether payment completed
- confirm whether ClubSpark already created the membership

## Stripe-Specific Troubleshooting

### Stripe page does not open

Check:
- popup blocker
- VPN
- in-app browser
- stale session

Member guidance:
- retry in a supported browser
- turn off VPN
- start the registration again in one clean tab

### 3D Secure or bank approval fails

Common causes:
- bank app approval does not return to browser cleanly
- embedded browser cannot handle redirect
- challenge times out
- privacy settings block the return flow

Member guidance:
- keep the original page open
- approve in the banking app
- return to the original tab
- retry on another device if needed

### Pending payment but uncertain outcome

Support action:
1. Ask the member not to retry yet.
2. Check whether ClubSpark already shows the membership.
3. Check whether a confirmation email was issued.
4. If unclear, wait for the pending payment to settle or fall away before recommending another attempt.

## ClubSpark Package Visibility Problems

If a member says a package is missing, check:
- signed-in person is correct
- DOB is correct
- package belongs to the correct season
- package eligibility depends on age or member type
- membership may already exist

## Internal Data Checks

When a payment appears successful but operations data is missing, check:
1. `raw_members`
2. `raw_contacts`
3. `member_signups`
4. `signup_batches`
5. missing-signup capture Metabase cards

Typical split:
- ClubSpark/Stripe issue: member cannot complete registration
- capture issue: registration completed but did not appear in `member_signups`

## Suggested Reply Patterns

### Suspected browser or VPN problem

Ask the member to:
- turn off VPN
- use Chrome, Edge, Safari, or Firefox
- avoid private browsing
- retry outside an in-app browser

### Unclear payment outcome

Ask the member to send:
- member name
- package
- approximate time
- screenshot
- whether the bank shows pending or completed payment

And tell them not to retry until checked.

### Profile data problem

Ask the member to review:
- name
- date of birth
- email address
- postal address

Especially for junior and family registrations.
