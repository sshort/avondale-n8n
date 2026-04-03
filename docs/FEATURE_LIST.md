# Avondale n8n Automation Platform - Feature Highlights

## What is Avondale n8n?

Avondale n8n is a powerful low-code automation platform that streamlines club membership management, replacing manual spreadsheets and email processing with intelligent, automated workflows.

---

## Key Features

### Automated Member Signup Processing
- **Email Parsing**: Automatically captures new member applications from Gmail, eliminating manual data entry
- **Batch Creation**: Intelligently groups new signups into processing batches
- **Status Tracking**: Complete visibility from new application through to completed onboarding

### ClubSpark Integration
- **Automated Exports**: Scheduled extraction of members and contacts data from ClubSpark
- **Full Refresh Capability**: Complete database sync with smart change detection
- **Session Management**: Secure authentication handling for API access

### Refund Management
- **Streamlined Requests**: Online refund request forms with instant processing
- **Status Tracking**: Real-time status updates for both staff and members
- **Treasury Integration**: Automated notification to treasurer for payment processing

### Label & Mailing Automation
- **No-Address Detection**: Automatically identifies members missing postal addresses
- **Smart Batching**: Groups members for label printing with envelope creation
- **Label and Envelope Printing**: Batch printing to modern label printers (J8160)
- **Postage Optimization**: DL envelope formatting for Royal Mail

### Data Synchronization
- **Historical Snapshots**: Automatic capture of membership statistics by season
- **Metabase Integration**: Live dashboards reflecting current system state

### Member Communications
- **Template Emails**: Personalized emails for welcome, reminders, and notifications
- **Team Captain Reports**: Automated contact list distribution to sports team captains
- **Gmail Integration**: Professional email delivery with tracking

### Team Sheet Management
- **Source Document Processing**: Automatically parses Word documents (`*.docx`) containing league and squad team lists
  - Ladies, Mens, Mixed, and Vets teams for summer seasons
  
- **Intelligent Player Matching**: Matches players against club membership data using multiple strategies:
  - Exact full name matching against `raw_members`, `vw_best_current_contacts`, `member_signups`, and `vw_junior_main_contacts`
  - Nickname/short-name expansion (e.g., "Jacquie" -> "Jacqueline")
  - Fuzzy matching for spelling variations
  - Manual override capability via `name_overrides.csv`
  
- **Multi-Format Output**: Generates team sheets in multiple formats:
  - `.xlsx` workbook with one squad per sheet
  - Per-sheet `.csv` files for easy import
  - Per-team `.pdf` files for printing and distribution
  - Branded with Avondale Tennis Club colours (navy, light blue, gold)
  
- **Captain Management**:
  - Identifies and marks captains (marked with `C` and bolded)
  - Keeps captains at top of each team list
  - Sorts remaining players alphabetically
  - Generates captain email distribution list automatically
  - Creates mailout manifests (`team-captain-email-jobs.json`, `.csv`)
  
- **Privacy & Consent Handling**:
  - Respects `Share Contact Detail` consent from `raw_contacts`
  - Independent consent tracking for juniors vs parents
  - Shows available contact details regardless of consent
  - Includes footnote explaining consent limitations for captains
  
- **Match Quality Tracking**:
  - `Exact` - Perfect name match
  - `Best Fit` - Chosen from duplicate contact rows
  - `Override` - Manual name override applied
  - `Nickname` - First-name expansion match
  - `Fuzzy` - Spelling variation match
  - `No Match` - Unable to match to club member
  
- **Review & Audit**:
  - Generates `NO_MATCH_NAMES.md` and `.pdf` showing unmatched players
  - Identifies "Not Signed Up" players (has contact but no current membership)
  - Provides match resolution transparency for quality assurance

### Manual Operations Support
- **Missing Signup Capture**: Backfill tool for members not automatically detected
- **Manual Batch Items**: Add shoe tags, parent tags, and keys without creating fake signups
- **Form-Based Interface**: Simple HTML forms for complex operations

### Metabase Dashboard & Reporting
- **Membership Overview Dashboard**: Complete view of club membership health
  - 7 tabs with 38 dashcards tracking all membership metrics
  - 42 questions/models powering the insights
  
- **Key Dashboards**:
  - **Membership Statistics**: Year-over-year comparison, new members, renewals, cancellations
  - **Signup Batches**: Full visibility into processing batches with consolidated payer addresses for labels
  - **Age Demographics**: Understand member distribution across age ranges
  - **Geographic Analysis**: Map visualization of member locations by year
  
- **Operational Dashboards**:
  - **n8n Execution Monitoring**: Track workflow performance, success rates, and recent executions
  - **Database Audit**: Global settings, raw match outcomes, ambiguous matches, and audit trails
  - **Key Management**: Summary of key holders, remaining cases, and completion tracking
  
- **Detection & Alerts**:
  - **Missing Signup Detection**: Automatically identifies members who haven't signed up for current season
  - **Address Validation**: Flags members missing postal addresses for mailings
  - **Package Changes**: Track members who changed membership packages
  
- **Analytics Features**:
  - **Signup Timing Analysis**: By day of week and hour to optimize marketing
  - **Email Delivery Tracking**: Identify members missing signup confirmation emails
  - **Historical Trends**: 10-year membership history with year-over-year comparisons
  - **Non-Active Member Tracking**: Monitor lapsed members for re-engagement

- **Data Quality**:
  - **Raw Match Auditing**: Track how member records are matched between systems
  - **Ambiguous Match Detection**: Identify records needing manual review
  - **Weak Match Alerts**: Flag matches based only on name similarity

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

## Technical Highlights

- **Low-Code Platform**: Easy to modify workflows without coding expertise
- **Cloud-Ready**: Scales with cloud PostgreSQL and Metabase
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

## Audit Trail & Data Reconciliation

The system maintains a comprehensive audit trail for member-contact matching and data reconciliation, tracked via the `raw_reconcile_match_audit` table.

### What Gets Tracked

- **Match Outcomes**: How records were matched between sources (exact match, ambiguous, weak name-only, no match, new record)
- **Source Records**: Which raw tables (members, contacts) and specific records were involved
- **Run Timestamps**: When each reconciliation run occurred
- **Match Confidence**: How confident the system is in each match

### Match Outcome Types

| Outcome | Description |
|---------|-------------|
| `exact_match` | Perfect match on name + address + membership |
| `ambiguous` | Multiple possible matches, needs manual review |
| `weak_name_only` | Only name matches, requires manual verification |
| `no_match` | No matching record found in other systems |
| `new_record` | New record created for a new member |

### Metabase Audit Dashboards

- **Latest Raw Match Outcomes**: Summary counts by outcome type per reconciliation run
- **Ambiguous Raw Matches**: Records with multiple possible matches requiring review
- **Weak Name-Only Raw Matches**: Low-confidence matches based only on name similarity
- **Latest Raw Match Audit**: Full audit trail for investigating specific records

### Business Value

- **Data Quality Visibility**: Immediately see which records need manual attention
- **Process Accountability**: Track who made matches and when
- **Compliance**: Full audit trail for GDPR and record-keeping requirements
- **Continuous Improvement**: Identify patterns in matching failures to improve processes