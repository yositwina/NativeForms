# TwinaForms GDPR Foundation Draft

**Status:** Draft for review, not yet approved for website publication  
**Created:** 2026-05-27  
**Scope:** Customer/controller role statement, Data Processing Agreement foundation, and Privacy Policy content

## Purpose

This document summarizes the proposed GDPR-facing foundation for TwinaForms before customer-facing website wording is changed.

The central distinction is:

- **Customer** means the company or organization that subscribes to, installs, configures, or uses TwinaForms.
- **Form Respondent** means the individual who views, completes, or submits a form published by the Customer.

TwinaForms should not claim that it never processes Form Respondent information. It processes submitted data as required to operate the configured form flow, run security checks, and write data to the Customer's Salesforce environment.

The accurate product position is:

- The Customer decides what Form Respondent information is collected and why.
- The Customer is generally the data controller for its forms.
- TwinaForms, operated by Harmony-IT, generally acts as processor for Customer form data.
- TwinaForms does not use submitted form content for its own advertising, marketing, or resale.
- Submitted data is intended to be written to the Customer's Salesforce environment.
- AWS may temporarily process submitted data and retain operational submission information.
- Where detailed submission logs are enabled, their private content is encrypted for access through the Customer's Salesforce environment, using customer-held private decryption material.

## Information Still Required Before Publication

Confirm these items before publishing privacy or DPA text:

1. Full registered legal name of Harmony-IT.
2. Registered or business address to display.
3. Privacy contact email: create `privacy@twinaforms.com` or use `supportat@twinaforms.com`.
4. Confirmation that the operating legal entity is established in Israel.
5. Contract governing law and jurisdiction for the DPA.
6. Initial process for customer data-export and deletion requests.
7. Notice mechanism for subprocessor changes.
8. Final position on Cloudflare Web Analytics consent/disclosure requirements for target markets.

## 1. Proposed Data Protection Role Statement

### English

**Our Data Protection Role**

When a Customer uses TwinaForms to create and publish forms, the Customer decides what information is collected through those forms, why it is collected, and how it is used in Salesforce. In this context, the Customer is generally the data controller and TwinaForms, operated by Harmony-IT, acts as a data processor providing the form publishing, submission, security, and operational logging services requested by the Customer.

A Customer is the company or organization using TwinaForms. A Form Respondent is the individual completing a form published by that Customer. TwinaForms does not determine which Form Respondent data a Customer collects and does not use submitted form content for TwinaForms marketing, advertising, or resale.

TwinaForms processes Form Respondent information only as needed to operate Customer-configured functionality, such as prefill, verification, submission, Salesforce writeback, document generation, malware scanning of uploaded files, and tenant-scoped operational troubleshooting.

Customers are responsible for providing appropriate privacy information to Form Respondents and ensuring that their collection and use of personal data is lawful.

For information collected directly through the TwinaForms website, account setup, commercial discussions, billing, service administration, or support communications, Harmony-IT may act as the data controller.

### Hebrew

**התפקיד שלנו בהגנת מידע**

כאשר לקוח משתמש ב-TwinaForms כדי ליצור ולפרסם טפסים, הלקוח קובע איזה מידע ייאסף באמצעות הטפסים, מדוע הוא נאסף וכיצד ייעשה בו שימוש ב-Salesforce. בהקשר זה, הלקוח הוא בדרך כלל בעל השליטה במידע, ו-TwinaForms, המופעלת בידי Harmony-IT, פועלת כמעבד מידע המספק את שירותי פרסום הטפסים, השליחה, האבטחה והיומנים התפעוליים שהתבקשו על ידי הלקוח.

לקוח הוא החברה או הארגון המשתמשים ב-TwinaForms. משיב לטופס הוא האדם שממלא טופס שפורסם על ידי אותו לקוח. TwinaForms אינה קובעת איזה מידע הלקוח אוסף ממשיבי הטפסים ואינה משתמשת בתוכן שנשלח בטפסים לצורכי שיווק, פרסום או מכירה חוזרת של TwinaForms.

TwinaForms מעבדת מידע של משיבי טפסים רק במידה הנדרשת להפעלת היכולות שהלקוח הגדיר, כגון מילוי מקדים, אימות, שליחה, כתיבה ל-Salesforce, יצירת מסמכים, סריקת קבצים שהועלו לאיתור תוכנות זדוניות ופתרון תקלות תפעולי מבודד לפי לקוח.

הלקוחות אחראים למסור למשיבי הטפסים מידע מתאים בנושא פרטיות ולוודא שאיסוף המידע האישי והשימוש בו נעשים כדין.

ביחס למידע שנאסף ישירות דרך אתר TwinaForms, הקמת חשבון, שיחות מסחריות, חיוב, ניהול השירות או פניות תמיכה, Harmony-IT עשויה לפעול כבעלת השליטה במידע.

## 2. Data Processing Agreement Foundation

### Document Header

**Document:** TwinaForms Data Processing Agreement  
**Effective date:** `[date]`  
**Parties:** `[Customer legal name]` ("Customer") and `[Harmony-IT full legal entity name]`, operator of TwinaForms ("TwinaForms")

### 2.1 Definitions And Roles

1. **Customer** means the company or organization that subscribes to, installs, configures, or uses TwinaForms. Customer does not mean an individual completing a Customer-published form.
2. **Form Respondent** means an individual who views, completes, or submits a form published by Customer using TwinaForms.
3. Customer determines the purposes and means of collecting and using personal data from Form Respondents through Customer-configured forms and Salesforce workflows. Customer is generally the controller for that data.
4. TwinaForms acts as processor when processing Form Respondent personal data solely to provide the configured service on Customer's behalf.
5. Harmony-IT may act as controller for Customer administrator, billing, sales, marketing-website, and support-contact information collected directly by Harmony-IT.

### 2.2 Processing Instructions

TwinaForms shall process personal data relating to Form Respondents only on behalf of Customer and only as necessary to:

- display and operate Customer-published forms;
- perform Customer-configured prefill, verification, submission, and Salesforce writeback workflows;
- process Customer-enabled files, signatures, and generated submission documents;
- scan uploaded files for malware before eligible files are attached to Salesforce records;
- maintain tenant-scoped operational submission logs, service security, and troubleshooting capability;
- provide, secure, maintain, and support the TwinaForms service;
- follow documented Customer instructions; or
- comply with applicable law.

TwinaForms shall not sell Form Respondent data or use submitted form content for independent advertising or marketing purposes.

### 2.3 Subject Matter And Purpose

TwinaForms allows Customer to:

- design and publish public forms connected to Salesforce;
- retrieve data from Salesforce for Customer-configured prefill flows;
- submit information into Customer-configured Salesforce records and workflows;
- process uploaded files, signatures, and submission documents where enabled;
- maintain operational logging and security controls;
- support and troubleshoot form operation.

### 2.4 Categories Of Personal Data

Depending on Customer configuration, personal data may include:

- names and contact information;
- form responses and free-text content;
- uploaded documents;
- signatures;
- Salesforce-related record identifiers;
- verification workflow data;
- prefill and submission values;
- submission status, timestamp, failure-stage, and operational troubleshooting information;
- any other fields intentionally selected by Customer.

Customer should not configure TwinaForms to collect special-category or highly sensitive data unless Customer has determined that the collection and processing are lawful, necessary, and appropriate.

### 2.5 Categories Of Data Subjects

Data subjects may include:

- Form Respondents;
- Customer administrators and authorized Customer users;
- Customer contacts, applicants, volunteers, donors, service users, employees, or other persons invited to use Customer-published forms;
- individuals whose Salesforce records are accessed or updated under Customer configuration.

### 2.6 Storage And Access Clarification

Personal data submitted through Customer forms is intended to be written to Customer's Salesforce environment according to Customer configuration.

TwinaForms may temporarily process submitted content in AWS to complete the requested workflow. TwinaForms may also retain limited operational metadata necessary to operate and support the service, including:

- form identifier and form-version identifier;
- submission timestamp and reference;
- success or failure outcome;
- failure stage;
- log mode and applicable retention metadata;
- Salesforce result identifier on successful completion where available.

Where detailed operational logs are enabled by plan and service setup:

- detailed log content is stored in encrypted form;
- AWS receives only the public encryption key needed to encrypt log details;
- the private decryption key remains in the Customer's Salesforce environment;
- authorized Customer users access detailed log content through Salesforce;
- detailed content is retained only under the applicable operational-log retention period.

This means TwinaForms should not state that it retains no submission data. It retains limited operational metadata and may retain encrypted detailed operational logs according to plan and configuration.

### 2.7 Confidentiality

TwinaForms shall ensure that authorized persons processing Customer personal data are subject to appropriate confidentiality obligations and access personal data only as required for their responsibilities.

### 2.8 Security Measures

TwinaForms shall maintain appropriate technical and organizational measures designed to protect Customer personal data, including where applicable:

- tenant-aware access controls and request validation;
- secure Salesforce authorization and package-to-AWS authentication;
- protected handling of credentials and signing material;
- encryption of detailed operational log content for eligible plan/configuration states;
- malware scanning of uploaded files before eligible files are attached to Salesforce records;
- deletion of temporary file-upload staging objects following processing or lifecycle expiry;
- operational monitoring and controlled troubleshooting access.

### 2.9 Subprocessors

Proposed initial subprocessor disclosure:

| Provider | Purpose | Current Notes |
|---|---|---|
| Amazon Web Services (AWS) | Hosting, runtime processing, operational logs, temporary upload processing, and malware scanning | TwinaForms runtime presently uses AWS `eu-north-1` (Sweden) |
| Salesforce | Customer-selected CRM platform receiving or providing form-related data | Data location and processing are subject to Customer's Salesforce agreement/configuration |
| Cloudflare | Analytics for the TwinaForms marketing website | Relevant to website visitor analytics, not Customer form response storage unless later configured otherwise |

The final DPA must define how Customers are notified of material subprocessor changes.

### 2.10 International Transfers

Proposed position:

- The TwinaForms AWS runtime is presently hosted in `eu-north-1` (Sweden), within the European Economic Area.
- Salesforce storage and processing locations depend on the Customer's Salesforce agreement and configuration.
- If confirmed, Harmony-IT is established in Israel, which is currently recognized by the European Commission as providing an adequate level of protection for EEA personal-data transfers.
- Where required for additional transfer paths or subprocessors, TwinaForms shall use appropriate lawful transfer safeguards.

### 2.11 Data Subject Requests

TwinaForms shall provide reasonable assistance to Customer in responding to applicable requests for access, correction, deletion, restriction, objection, or portability relating to personal data processed through Customer forms.

If a Form Respondent contacts TwinaForms concerning data controlled by Customer, TwinaForms may direct that individual to Customer and assist Customer as required, unless applicable law requires TwinaForms to respond directly.

### 2.12 Retention And Deletion

Proposed retention position:

1. Data written into Salesforce is retained according to Customer's Salesforce configuration and policies.
2. Operational submission logs in AWS are retained according to the Customer's applicable plan and service configuration.
3. Current operational-log retention schedule:

| Plan | Operational Log Retention |
|---|---:|
| Trial | 30 days |
| Starter | 90 days |
| Pro | 365 days |

4. Temporary uploaded files staged for malware scanning or processing are deleted after completed processing or automated lifecycle expiry. Current cleanup target for abandoned staged objects is no more than one day.
5. Upon termination or documented Customer request, TwinaForms shall delete or return personal data processed on Customer's behalf, subject to legal obligations, customer-controlled Salesforce retention, and the documented operational-log retention/deletion process.

### 2.13 Personal Data Breach Notification

TwinaForms shall notify Customer without undue delay after becoming aware of a personal data breach affecting Customer personal data processed by TwinaForms and shall provide available information reasonably necessary for Customer to meet its applicable obligations.

Decision still required: whether the commercial DPA promises a specific initial notification target, such as 48 hours after confirmation.

### 2.14 Audit And Compliance Assistance

TwinaForms shall make available information reasonably necessary to demonstrate its processor obligations and reasonably cooperate with Customer assessments or audits, subject to confidentiality, security, proportionality, and reasonable frequency limits.

### 2.15 Customer Responsibilities

Customer is responsible for:

- determining the lawful purpose and legal basis for Customer forms;
- selecting which fields and documents are collected from Form Respondents;
- providing required privacy information to Form Respondents;
- configuring Salesforce access, workflow, storage, and retention appropriately;
- responding as controller to Form Respondent privacy rights requests;
- avoiding unnecessary or unlawful collection of personal data;
- maintaining its Salesforce environment and authorized access.

## 3. Privacy Policy Foundation

### Proposed English Content

#### Privacy Policy

**Effective date:** `[date]`

TwinaForms is a product operated by `[Harmony-IT full legal entity name]` ("Harmony-IT", "TwinaForms", "we", "us"). This Privacy Policy explains how we process personal data through the TwinaForms website, customer account and support activities, and the TwinaForms service.

For privacy questions or requests, contact: `[privacy contact email]`  
Business address: `[registered/business address]`

#### Our Role

When a Customer uses TwinaForms to create and publish forms, the Customer determines what information is collected through those forms, why it is collected, and how it is used in Salesforce. A Customer is the company or organization using TwinaForms; an individual completing a Customer-published form is a Form Respondent.

For personal data submitted by Form Respondents through Customer forms, the Customer is generally the data controller and TwinaForms acts as a processor providing the Customer-configured service.

TwinaForms does not determine which submitted fields a Customer collects and does not use submitted form content for TwinaForms advertising, marketing, or resale.

For personal data collected directly through our website, account setup, commercial discussions, billing, service administration, and support interactions, Harmony-IT may act as data controller.

#### Information We Process

We may process:

- website enquiry and support-contact information;
- customer organization, account, administrator, subscription, and setup information;
- Salesforce organization identifiers and connection status;
- Customer-configured form responses, uploaded files, signatures, verification data, prefill values, and writeback values;
- submission status, timestamps, security events, and operational troubleshooting records.

Customers choose the fields their forms request and the Salesforce actions their forms perform.

#### Purposes And Legal Bases

Where Harmony-IT acts as controller, processing purposes and typical bases include:

| Purpose | Typical Basis |
|---|---|
| Answering enquiries and requested information | Legitimate interests or pre-contract steps |
| Customer account and service administration | Performance of contract |
| Technical support and service reliability | Performance of contract and legitimate interests |
| Security and abuse prevention | Legitimate interests |
| Required business records | Legal obligation |
| Website analytics | Legitimate interests or consent where required |

Where TwinaForms acts as processor for Customer forms, the Customer determines the applicable lawful basis.

#### Customer Forms And Form Respondents

TwinaForms processes Form Respondent data only as necessary to operate Customer-configured form functions, such as:

- form display and validation;
- prefill from Salesforce;
- User Verification;
- submission and Salesforce writeback;
- document generation and signatures;
- file upload processing and malware scanning;
- operational troubleshooting and security monitoring.

Submitted data is intended to be stored in the Customer's Salesforce environment according to Customer configuration and policies.

#### AWS Processing And Security

TwinaForms uses Amazon Web Services to operate public form runtime functions and supporting infrastructure. Current AWS runtime processing is hosted in `eu-north-1` in Sweden.

Security and operational measures include where applicable:

- tenant-aware runtime validation;
- controlled Salesforce connectivity;
- protected authentication and signing material;
- encrypted detailed operational logs;
- malware scanning of uploaded files before eligible files are attached to Salesforce records;
- deletion of temporary uploaded file staging objects after processing or automated lifecycle expiry.

#### Operational Submission Logs

TwinaForms may retain operational submission logs in AWS to provide support, troubleshoot failed submissions, maintain reliability, and manage service limits.

Operational metadata may include the form identifier, submission time, submission reference, success or failure outcome, failure stage, and applicable retention information.

Where detailed log content is enabled, private operational content is encrypted. AWS receives the public encryption key used for encryption, while the private decryption key remains in the Customer's Salesforce environment for access by authorized Customer users.

Current intended operational-log retention periods are:

| Plan | Retention |
|---|---:|
| Trial | 30 days |
| Starter | 90 days |
| Pro | 365 days |

#### File Uploads

Where Customer enables file uploads, files may be staged temporarily in AWS while processed. Eligible uploaded files are scanned for malware before they can be attached to Salesforce records. Files that do not pass required safety checks are not attached to Salesforce. Staged files are deleted after completed processing or by automated lifecycle cleanup.

#### Website Analytics

The TwinaForms marketing website currently uses Cloudflare Web Analytics to help understand website usage and maintain the site. TwinaForms will disclose and operate analytics according to applicable privacy and electronic communications requirements, including obtaining consent where required.

#### Service Providers And International Transfers

Relevant providers currently include AWS, Salesforce, and Cloudflare. AWS runtime processing for TwinaForms is presently hosted in Sweden within the EEA. Salesforce processing locations depend on Customer's Salesforce contract and configuration.

If confirmed before publication: Harmony-IT is established in Israel, and Israel is currently recognized by the European Commission as providing adequate protection for personal-data transfers from the EEA.

Where required, appropriate safeguards will be used for transfers outside the EEA.

#### Retention

TwinaForms retains personal data only as reasonably necessary for the described purposes, including operating accounts, providing support, meeting contractual and legal obligations, maintaining security, and retaining operational logs for their stated periods.

Customers control the retention of personal data stored in their Salesforce environment.

#### Individual Rights

Where applicable, individuals may have rights to request access, correction, deletion, restriction, objection, portability, withdrawal of consent where relevant, and to lodge a complaint with a competent data protection authority.

If information was submitted through a Customer form, the Form Respondent should generally contact that Customer first because the Customer controls the form data. TwinaForms will assist the Customer where required.

For information controlled directly by Harmony-IT, contact `[privacy contact email]`.

### Hebrew Public Summary Candidate

The final Hebrew Privacy Policy should be a complete translation of the approved English policy. A concise public summary for the privacy or security page may be:

**נתוני הטפסים נשארים בשליטת הארגון שלכם**

הארגון שלכם קובע איזה מידע כל טופס אוסף וכיצד מידע שנשלח משמש ב-Salesforce. ‏TwinaForms מעבדת תשובות רק לצורך הפעלת זרימת הטופס שהגדרתם, בדיקות אבטחה ותמיכה תפעולית. תוכן מפורט ביומנים התפעוליים מוצפן לצורך גישה דרך סביבת ה-Salesforce שלכם.

## 4. Website Claim Guidance

Do not publish the absolute claim `GDPR compliant` until the DPA, full privacy notice, subprocessor/transfer disclosures, data-subject request procedure, retention/deletion procedure, and legal review are completed.

Safer interim marketing wording:

> **Designed to support GDPR-conscious form processing.**  
> TwinaForms helps organizations collect form data securely using Salesforce and AWS, with controlled access, encrypted operational logs, malware-scanned uploads, and configurable retention.

Or:

> **Privacy and security built in**  
> Your organization decides what each form collects and how submitted information is used in Salesforce. TwinaForms processes responses only to provide your configured workflow, security checks, and operational support.

## 5. Implementation And Publication Checklist

Before website publication:

- confirm legal entity, address, privacy contact, and Israel establishment;
- approve complete English Privacy Policy;
- translate and review complete Hebrew Privacy Policy;
- approve customer DPA and delivery/acceptance mechanism;
- create or publish a subprocessor disclosure;
- define Customer deletion/export request handling;
- verify and document Cloudflare Web Analytics consent/disclosure approach;
- obtain legal review before any absolute compliance claim.

## Reference Sources

- European Data Protection Board, data controller and processor roles:  
  <https://www.edpb.europa.eu/sme-data-protection-guide/data-controller-data-processor_en>
- European Commission, data protection by design and by default:  
  <https://commission.europa.eu/law/law-topic/data-protection/rules-business-and-organisations/obligations/what-does-data-protection-design-and-default-mean_en>
- European Data Protection Board, international transfers and adequacy decisions:  
  <https://www.edpb.europa.eu/sme-data-protection-guide/international-data-transfers_en>
- AWS GDPR Center:  
  <https://aws.amazon.com/compliance/gdpr-center/>
