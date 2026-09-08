# TwinaForms AgentExchange Solution Intake Questionnaire Answers

Date: 2026-08-31

Package: TwinaForms managed 2GP package `0.14.0.1`

AppExchange / Subscriber Package ID: `033gL0000009ZbFQAU`

Subscriber Package Version ID: `04tgL000000OO9FQAW`

Prepared for OSV / AppExchange Security Review.

Review status: Draft pending final verification of the OSV review org.

Do not submit this questionnaire until the review org has been verified to have TwinaForms package version `0.14.0.1` installed and an Agentforce agent configured to invoke the packaged action.

## AgentExchange Solution Intake Questionnaire

### 1. If the submitted package is an extension package:

Question: Has the base package passed security review? If the base package is also in the security review queue, share its solution name, package ID, and package version ID.

Answer: Not applicable. The submitted package is the core TwinaForms managed 2GP package, not an extension package.

Solution name: `TwinaForms`

Package ID: `033gL0000009ZbFQAU`

Package version ID: `04tgL000000OO9FQAW`

Package version: `0.14.0.1`

### 2. Are all dependencies installed and configured in the org submitted for security review?

Answer: Pending final review-org verification before submission. The submitted package includes the packaged Apex invocable action `NativeFormsAgentforceActions.createFormFromPageLayout`, the TwinaForms Designer, page-layout import logic, Salesforce custom objects, permission sets, and AWS callout integration used by the product.

Before submitting this questionnaire, the OSV review org should be verified to have:

1. TwinaForms managed package `0.14.0.1` installed.
2. The packaged Apex class `NativeFormsAgentforceActions` available.
3. Salesforce Agentforce enabled in the review org.
4. An Agentforce agent/topic/action setup configured to call `Create TwinaForms Form from Page Layout`.
5. A tested end-to-end prompt that creates a Draft TwinaForms form and returns a Designer URL.

For Agentforce-specific testing, the review org must have Salesforce Agentforce available/enabled because Agentforce itself is a Salesforce platform capability, not a third-party dependency packaged by TwinaForms.

### 3. What agent type does the solution depend on? If the solution requires multiple agents, list the topics associated with each agent.

Answer: TwinaForms depends on an admin-facing Salesforce Agentforce agent that can invoke a public Apex action. The supported use case is form-authoring assistance for Salesforce admins.

Agent type: Salesforce Agentforce admin/internal employee agent.

Topic / use case: Create a TwinaForms draft form from a Salesforce object page layout.

The package does not require multiple agents. It does not include a customer-facing public chatbot, service agent, or autonomous background agent.

### 4. Is the agent configured and set up with end-to-end use cases in the org submitted for review?

Answer: Pending final review-org verification before submission. The package includes the Apex action required for the end-to-end use case. The review org should be configured so OSV can test this end-to-end Agentforce use case:

1. A Salesforce admin asks Agentforce to create a TwinaForms form from a Salesforce page layout, for example Contact.
2. Agentforce calls the packaged Apex invocable action `Create TwinaForms Form from Page Layout`.
3. The action reads Salesforce page-layout metadata through existing TwinaForms package logic.
4. The action creates a Draft TwinaForms form/version/element structure inside Salesforce.
5. The action returns the draft form id, version id, field counts, warnings when applicable, and a TwinaForms Designer URL.
6. The Salesforce admin opens the draft in TwinaForms Designer, reviews it, adjusts it if needed, and publishes through the normal TwinaForms publish flow.

The Agentforce action does not publish automatically and does not submit data to Salesforce records automatically. Publication remains under human admin control.

Final submission answer should be changed to `Yes` only after the OSV review org has been verified with this setup.

### 5. Provide details about all public agent actions in the solution.

| Action Name | Action Type | Describe Why the Action Is Public |
| --- | --- | --- |
| `Create TwinaForms Form from Page Layout` | Apex invocable action, implemented by `NativeFormsAgentforceActions.createFormFromPageLayout` | The action is public/global so subscriber admins and Agentforce can discover and invoke it from the installed managed package. It is intended for authenticated Salesforce admin use inside the subscriber org. The action creates Draft TwinaForms metadata records only and returns a Designer URL for human review. It does not expose credentials, does not call a third-party LLM, does not publish a form automatically, and does not bypass Salesforce authentication, package permissions, Apex sharing, or TwinaForms validation. |

### 6. If the solution depends on unmanaged code and metadata, share details about the dependencies.

Answer: The TwinaForms package does not depend on unmanaged code or unmanaged metadata for the packaged Agentforce action. The action is implemented in managed package Apex.

The customer/reviewer may configure an Agentforce agent, topic, or action assignment in the review org to test the use case. That Agentforce setup is Salesforce platform configuration for testing and is not a TwinaForms unmanaged code dependency.

### 7. If the solution uses Messaging for In-App and Web (MIAW) integration, share details including the end-to-end use cases.

Answer: Not applicable. TwinaForms does not use Salesforce Messaging for In-App and Web (MIAW) for the Agentforce feature submitted here.

### 8. Does the solution use any third-party large language model (LLM) APIs directly? For example, it makes direct API calls to OpenAI APIs.

Answer: No. TwinaForms does not make direct API calls to OpenAI APIs or other third-party LLM APIs.

The Agentforce functionality uses Salesforce Agentforce to call a packaged Salesforce Apex invocable action. The TwinaForms package action itself is deterministic Apex logic that creates a Draft form from Salesforce page-layout metadata and returns a Designer URL for review.

## MCP Server Intake Questionnaire

### 1. MCP Server Endpoints

Question: Full list of MCP server endpoints and MCP protocol version being used.

Answer: Not applicable. TwinaForms does not include or operate an MCP server as part of this AppExchange submission.

### 2. API Endpoints

Question: List all API endpoints and provide Postman collection or sample API request/response with required input parameters for testing.

Answer: Not applicable for MCP server review because TwinaForms does not include an MCP server.

TwinaForms AWS and Salesforce API endpoints used by the product are documented separately in `TwinaForms_Sample_API_Callouts_2026-08-24.md`, and ZAP evidence is included in the `zap` folder of the 0.14 submission packet.

### 3. AuthN/AuthZ Flow

Question: Complete end-to-end documentation of authentication and authorization flow, including token issuance, validation, rotation, and access controls.

Answer: Not applicable for MCP server review because TwinaForms does not include an MCP server.

The product authentication and authorization model is documented separately in `TwinaForms_Data_Flow_Authentication_Encryption_and_Usage_2026-08-24.md`.

### 4. Credential Storage

Question: Details on where sensitive data is stored and confirmation that no default or hardcoded secrets exist.

Answer: Not applicable for MCP server review because TwinaForms does not include an MCP server.

For the TwinaForms product, Salesforce OAuth refresh tokens and central OAuth client configuration are stored in AWS Secrets Manager. Package service signing secrets are generated per org and stored in protected package-managed Salesforce storage and the org-specific AWS connection secret. The Code Analyzer and Source Scanner explanation documents identify remaining scanner findings as false positives or accepted public values; no default or hardcoded secrets are intentionally shipped.

### 5. Architecture

Question: Network architecture diagram showing MCP server placement and connections to Salesforce and other internal/external services.

Answer: Not applicable. There is no MCP server placement in the TwinaForms architecture.

The TwinaForms product architecture and data flow are documented separately in the 0.14 security review packet.

### 6. Data Classification

Question: Business context and data sensitivity classification for data accessed or handled by the MCP server.

Answer: Not applicable for MCP server review because TwinaForms does not include an MCP server.

For the TwinaForms product, data can include Salesforce form metadata, public form definitions, submitted form values, submission status/log metadata, and connected-org portable form snapshots. Submitted form values can be sensitive customer data depending on the customer's form configuration. Sensitive submission-log details are encrypted when detailed logs are enabled.

### 7. Testing Environment

Question: Details of an isolated testing environment with end-to-end working Agent setup in an org where the security review can be conducted.

Answer: Not applicable for MCP server review because TwinaForms does not include an MCP server.

For TwinaForms package testing, the test environment details are documented in:

- `TwinaForms_Test_Environment_Username_Password_Access_2026-08-24.md`
- `TwinaForms_Test_Environment_API_OAuth_SAML_Access_2026-08-24.md`

Agentforce testing requires Agentforce to be enabled in the review org and configured to invoke the packaged public Apex action.

### 8. Third Party Credentials

Question: Provide third-party application/resource server credentials integrated with the MCP server/Salesforce org for testing, two service-agent user credentials for authorization testing, and DAST scan report.

Answer: Not applicable for MCP server review because TwinaForms does not include an MCP server.

TwinaForms does not require reviewers to receive third-party LLM credentials. DAST/ZAP reports for the product endpoints are included in the 0.14 submission packet under the `zap` folder.

## Review Org Verification Checklist

Use this checklist before replacing the pending answers with final `Yes` answers and submitting to OSV.

### Documented Review Org

Current documented review org in the 0.14 test-access document:

- Environment name: `TwinaForms ISV Review Test Org`
- Login URL: `https://orgfarm-a1b98a9cb1-dev-ed.develop.lightning.force.com/`
- Username: `yositwina.4af3e518a88a@agentforce.com`
- Required package version: `0.14.0.1`
- Required subscriber package version ID: `04tgL000000OO9FQAW`

### Required Verification

1. Confirm that `yositwina.4af3e518a88a@agentforce.com` is the org OSV will use.
2. Confirm TwinaForms `0.14.0.1` is installed in that org.
3. Confirm the installed package contains `NativeFormsAgentforceActions`.
4. Confirm Agentforce is enabled in that org.
5. Confirm an Agentforce agent/topic/action is configured to invoke `Create TwinaForms Form from Page Layout`.
6. Test this prompt or equivalent: `Create a TwinaForms form from the Contact page layout.`
7. Confirm the action returns success, creates a Draft TwinaForms form, and returns a Designer URL.
8. Open the Designer URL and confirm the draft can be reviewed before publishing.

### Current CLI Verification Status

As of 2026-08-31, the documented review org username `yositwina.4af3e518a88a@agentforce.com` is not authorized in the local Salesforce CLI, so Codex could not verify the installed package version or Agentforce setup directly.
