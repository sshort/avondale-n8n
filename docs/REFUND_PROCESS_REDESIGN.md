
Redesign the refund process

- use the existing refund resource where possible.  Modify them as you need to.
- all email messages should use the email-templates mechasism, with preview and edit before send
- all email request should allow test mode
- all error messages should be returned to the landing page for display.
- The user should not see JSON in their browse window, of the landing page cannot be used of this then create a new page for email send status. 

## Landing page
- the landing / home page has the webhook path /refunds, which lists the refunds and shows their status
- the refunds page has a button that allows you to create a new refund request, which opens the create refund page.
- the status lifecycle for refunds is: New Request, Request Bank Details, Bank Details Obtained, Submitted for Refund, Refund Processed, Refund Rejected
- clicking on a refund should display the appropriate action buttons based on the status of the refund

## Create refund page
- the create refund page returns a succuess or failure error message which is then displayed on the refunds home page
- the member name should be populate by searching for name or email address, but should also allow free form entry
- the requestor name should be populate by searching for name or email address, but should also allow free form entry

# Request Banki Details
- Request Bank Details should be an action on each refund that has the status New Request or Request Bank Details
- Request Bank Details should construct an email using an email template, display a preview of the email and allow sending. 
- Once sent, the refund status should be updated

# Submit Refund Request
- Submit Refund Request should be an action on each refund that has the status Bank Details Obtained or Submitted for Refund
- Submit Refund Request should construct an email using an email template, display a preview of the email and allow sending.
- Once sent, the refund status should be updated
