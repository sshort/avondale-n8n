# Avondale n8n Automation Platform - Feature Highlights

## What is Avondale n8n?

Avondale n8n is a powerful low-code automation platform that streamlines club membership management, replacing manual spreadsheets and email processing with intelligent, automated workflows.

---

## Key Features

### Metabase Dashboard & Reporting
- **Membership Overview Dashboard**: Complete view of club membership health
- **Membership Statistics**: Year-over-year comparison, age distribution, 10-year membership history trends
- **Signup Statistics**: Latest signups, missing signup detection, visial map, new members, non-renewals, package changes
- **Signup Batches**: Full visibility into processing batches, ability to generate labels and envelops
- **Batch Executions**: Status of all workflow executions
- **Key Management**: Summary of key holders, key stock, unknown cases, and automatic stock reduction when keys are sent
- **Database Audit**: Global settings, raw match outcomes, ambiguous matches, weak matches and audit trails
- **Refund Management**: View refunds, create and calculate refunds, track refund related emails
- **Non-Active Member Tracking**: Monitor lapsed members for re-engagement

### Automated Member Signup Processing
- **Email Parsing**: Automatically captures new member applications from Gmail, eliminating manual data entry
- **Batch Creation**: Intelligently groups new signups into processing batches
- **Label Printing**: Batch print address labels - for larger batches
- **Envelope Printing**: Envelope printing - for smaller batches
- **No-Address Detection**: Automatically identifies members missing postal addresses
= **Backfill Missing Signups**: Backfill missing signups for members who have registered using ClubSpark
- **Templated Emails**: Personalized emails for reminders, and notifications
- **Status Tracking**: Complete visibility from new application through to completed onboarding

### ClubSpark Integration
- **Automated Exports**: Scheduled extraction of members and contacts data from ClubSpark

### Refund Management
- **Refund Report**: List of all refund requests with status and email tracking
- **Create Refund Requests**: Create refund requests
- **Treasury Integration**: Send email request to treasurer for payment processing

### Member Lookup
- **Member Search**: Fast member search, multiple member search - to fulfil contact requests from team organisers and captains
- **Member Details**: View consolidated member details page - recent memberships, signups, batch information
- **Add Tags And Keys**: Manually add tags and keys for members for lost tags and when members do not register using ClubSpark
- **Template Emails**: Personalized emails for reminders, and notifications

### Case Tracking
- **Web-Based Case UI**: Lightweight case management served via n8n webhooks with DaisyUI
- **Dashboard View**: Case statistics, active/waiting/completed counts, free-text search, status and priority filters
- **Case Management**: Create, update, and track cases through status (In Progress, Waiting, Completed) and priority (Low, Medium, High, Urgent)
- **Activity Tracking**: Internal notes and outbound emails stored against each case
- **Gmail Integration**: Two-way sync with Gmail labels (In Progress, Waiting, Completed)
  - Imports Gmail threads into the case database
  - Pushes status changes back to Gmail labels
- **Contact Search**: Searches club contacts from cleaned data sources (raw_contacts, raw_members, vw_best_current_contacts)
- **Email Templates**: Compose and preview emails using message templates and signatures
- **Settings Management**: Configure email delivery mode, test recipient, sender name, reply-to, and default signature

### Team Sheet Management
- **Source Document Processing**: Automatically parses Word documents (`*.docx`) containing league and squad team lists
  - Ladies, Mens, Mixed, and Vets teams for summer seasons
  
- **Intelligent Player Matching**: Matches players against club membership data using multiple strategies:
  - Exact full name matching against `raw_members`, `vw_best_current_contacts`, `member_signups`, and `vw_junior_main_contacts`
  - Nickname/short-name expansion (e.g., "Jacquie" -> "Jacqueline")
  - Fuzzy matching for spelling variations
  - Manual override capability via `name_overrides.csv`
  - Match Quality Tracking: 
    - `Exact` - Perfect name match
    - `Best Fit` - Chosen from duplicate contact rows
    - `Override` - Manual name override applied
    - `Nickname` - First-name expansion match
    - `Fuzzy` - Spelling variation match
    - `No Match` - Unable to match to club member
  
- **Multi-Format Output**: Generates team sheets in multiple formats:
  - `.xlsx` workbook with one squad per sheet
  - Per-sheet `.csv` files for easy import
  - Per-team `.pdf` files for printing and distribution
  
- **Email Management**:
  - Generates captain email distribution list automatically
  - Creates mailout manifests (`team-captain-email-jobs.json`, `.csv`)
  - Sends emails to captains with selectable team sheet attachments
  
- **Review & Audit**:
  - Generates `NO_MATCH_NAMES.md` and `.pdf` showing unmatched players
  - Identifies "Not Signed Up" players (has contact but no current membership)
  - Provides match resolution transparency for quality assurance

---

## Business Benefits

| Benefit | Impact |
|---------|--------|
| **Time Savings** | Eliminates hours of manual data entry and spreadsheet work |
| **Error Reduction** | Automated processing means fewer mistakes |
| **Better Visibility** | Real-time dashboards show membership health |
| **Faster Onboarding** | New members processed within minutes, not days |
| **Professional Image** | Automated communications look polished and consistent |
| **Compliance** | Audit trail built into every operation |

---

### Business Value

- **Data Quality Visibility**: Immediately see which records need manual attention
- **Process Accountability**: Track who made matches and when
- **Compliance**: Full audit trail for GDPR and record-keeping requirements
- **Continuous Improvement**: Identify patterns in matching failures to improve processes

---

## Technical Highlights
- **AI Generated**: All the heavy lifting was implemented by AI
- **Low-Code Platform**: Easy to modify workflows without coding expertise
- **Self-Hosted**: Complete control over your data
- **Modular Design**: Each workflow is independent and maintainable
- **Scheduled & Event-Driven**: Runs on schedule or responds to triggers

---

## Automation Summary

- **40+ workflows** covering the full membership lifecycle
- **End-to-end automation** from email signup to label printing
- **Zero manual intervention** for standard operations
- **Audit trail** on every action for compliance

---
