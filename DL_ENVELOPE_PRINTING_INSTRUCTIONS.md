## DL Envelope PDF

Workflow:
- `Print DL Envelopes from Cloud`

Webhook:
- `http://n8n:5678/webhook/download-dl-envelopes`

Output:
- PDF sized for `220 x 110 mm` DL envelopes
- `avondale_banner.png` at the top left
- recipient address on the right side
- package `count + icon` badges at the bottom left

## Canon TS5100

Recommended settings:
- paper source: `Rear Tray`
- media size: `DL Envelope` or custom `220 x 110 mm`
- media type: `Envelope`
- print quality: `Standard`
- scaling: `100%` or `Actual Size`

Loading guidance:
- load the envelope in the rear tray
- print side facing you
- flap closed
- follow the Canon driver flap-orientation diagram if it appears

Notes:
- print one test envelope first
- if the first print is upside down or feeds the wrong way, change the envelope orientation in the tray rather than changing the PDF
- avoid `Fit to page`, `Shrink oversized pages`, or any automatic scaling
