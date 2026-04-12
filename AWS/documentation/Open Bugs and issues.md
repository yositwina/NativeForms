# Bug Tracker

## Open
- [ ] BUG-001 Add hints
  - Status: Open
  - Severity: Medium
  - Area: SF user pages 
  - File: 
  - Description: Add hints how to use the system.
  - Actual: Partial
  - Notes: keep simple

- [ ] BUG-002 error messgae on fail submit form
  - Status: Open
  - Severity: High
  - Area: Submit-lambda
  - File: lambda/submit/index.mjs
  - Description:  Error fils shoud be clear , we need to define set of error messages i.e Authenication not set up, subscription end, faile to deploy to sf fields not matched.  we need to discuss this feature
  - Example : Query failed. Status: 400. Body: [{"message":"\nContact WHERE Email = liam.carter@example.com ORDER BY CreatedDate\n ^\nERROR at Row:1:Column:54\nunexpected token: '@'","errorCode":"MALFORMED_QUERY"}]
  
- [X] BUG-003 NF themes Object fiels deiplays
  - Status: Solved
  - Severity: High
  - Area: nativeForms Admin app
  - File:
  - Description: on NF Theme object plesae add on page layot to show al lfields, currently no field is shown
  - Actual: 

[ ] BUG-004 Publish failed
- Severity: High
- Description: when external credential are not set correctly by user on Permission set he get teh below error insteasd of a simple mssage youe external credentail are not set correctly (and instructions what to do) 
System.CalloutException: We couldn't access the credential(s). You might not have the required permissions, or the external credential "NativeFormsLambdaAuth" might not exist. @ Class.NativeFormsAwsClient.presignHtml: line 48, column 1


[X] BUG-005 Pudblish Link
- Severity: High
- Type: feature
- Description: On Designer Page Once a Form is publishes,If this version is selected teh link to teh form should appear (near teh wording "This published version is read-only. Publish creates a new draft copy for continued editing."

[X] Bug 006 NativeForm Connect Page
- Status: Solved
- Actual:
  - Updated connect-page wording and layout text.
  - Tenant secret is shown in the UI for 5 minutes only.
  - After 5 minutes the page stops showing the code and tells the user to use the admin email inbox.
- text cahnges below, keep bold part bold as today
Finish NativeForms Setup  --> You need to finish NativeForms Setup ,please gollow below instructions (in bold)

Open the
NativeForms Admin
permission set in Salesforce Setup and assign it to the admins who will manage the app.
 --> 
Open the NativeForms Admin 
permission set in Salesforce Setup and assign it to the admins who will manage the app.
In that permission set, open External Credential Principal Access

Open
External Client App Manager

and choose the
NativeForms

app. Go to the
Settings

tab, then under
OAuth Settings

click the button to view the
Consumer Key

and
Consumer Secret 
-->
Open  External Client App Manager

and choose the NativeForms

app. Go to the Settings

tab, then under OAuth Settings

click the button to view the Consumer Key
and
Consumer Secret

- Tenant Secret Code

oUo_ZuXUW3jIUQgQ-jehIo5oyXhLiQfa7sXmLdT-TQY
plese delete the code after 5 minutes and nevert show it again 9add text that explain this), teh code is in teh email box of admin
