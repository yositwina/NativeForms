# Form demo 1:

- Name Contact details update demo
- Form key should use the standard `formN` format and be assigned from the next available numeric index during demo install.
- Section with the following fields
First Name	Last Name (required)
Email		Phone
[](checkbox) I agree to accept emails

- Layout
  Left column: First Name, Email, opt-in checkbox
  Right column: Last Name, Phone

- Form Setting
CAPTCHA is ON

- Prefil object
Alias: PrefilContact  - contact, findone, Ignore
condition: Email Equal URL Parameter, email
Prefill fields ( all fields), please set the rules on element property
Submit object
Alias: SubmitContact  - contact, find and update exiting record  else create new record
match condition: Email Equal Form Field,  Email

- Submit  fields ( all fields), please set the rules on element property

# Form demo 2:

- Name: Prefill multi record demo
- Form key should use the standard `formN` format and be assigned from the next available numeric index during demo install.
- Section with the following fields
First Name	Last Name (required)
Email		Phone

- Layout
  Contact details left column: First Name, Email
  Contact details right column: Last Name, Phone

Repeating Group element with 2 columns case object (see below prefill)
Subject, Priority, CaseId hided field) (under priority) 

- Related Cases row layout
  Left column: Subject
  Right column: Priority, hidden CaseId

- Form Setting
CAPTCHA is ON

- Prefil object
Alias: PrefilContact  - contact, findone, Ignore
condition: Email Equal URL Parameter, email
Alias2: PrefilCase  - Case, findMany, Ignore
condition: contactId  Equal Prefill alias field, contact, Id
Prefill fields ( all contact fields), please set the rules on element property with alias prefilConatct
Prefill fields ( all case  fields), please set the rules on element property with alias prefilCases


- Submit object
Alias: SubmitContact  - contact, find and update exiting record  else create new record
match condition: Email Equal Form Field,  Email

Alias: SubmitCase  - Case, find and update exiting record,  else create new record
match condition: caseId Equal Form Field,  CaseId

Submit  fields ( all contact and case fields), please set the rules on element property

