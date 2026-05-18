# Salesforce Code Analyzer ProtectSensitiveData Response

Date: 2026-04-29

This note explains the remaining `ProtectSensitiveData` findings from Salesforce Code Analyzer. Each item below is an open analyzer finding and explains why the field is not storing a password, private secret, or user credential.

## `NF_Form_Action__c.Command_Key__c`

The field name includes `Key`, so the analyzer reports it as a possible auth token.

This field stores a stable generated command identifier for a form action. It is a running identifier created by the package and used as an input key when designing forms and mapping submit or prefill action results back to the configured action. It is not a password, API key, OAuth token, or secret value.

## `NF_Form_Element__c.Field_Key__c`

The field name includes `Key`, so the analyzer reports it as a possible auth token.

This field stores a stable generated field identifier for a form input. It is a running identifier created by the package and used as an input key when designing forms and mapping submitted form JSON to the correct form element. It does not grant access to any system and does not contain secret material.

## `NF_Form_Publication__c.Publication_Status__c`

The field name includes text that matched the analyzer rule.

This field is a restricted picklist for the publication job state. Values are operational statuses such as `Pending`, `Success`, and `Failed`. It contains no secret or credential data.

## `NF_Form_Publication__c.Publication_Type__c`

The field name includes text that matched the analyzer rule.

This field is a restricted picklist for the publication operation type. Values describe the action being performed, such as `Publish`, `Republish`, `Unpublish`, or `Register Only`. It is not an authentication value.

## `NF_Form_Version__c.Publish_Token__c`

The field name includes `Token`, so the analyzer reports it as possible sensitive data.

This value is a per-form publish identifier used to establish trust and routing between the published HTML form hosted on AWS and the TwinaForms AWS service that handles form submissions. It helps the AWS submit service identify the relevant published form artifact. It is not a user credential, OAuth refresh token, API secret, or org-wide access token. It does not allow a user to sign in or access Salesforce.

## `NF_Form__c.NF_Key__c`

The field name includes `Key`, so the analyzer reports it as a possible auth token.

This field stores a stable generated form identifier. It is a running identifier created by the package and used as a form key when designing forms and when the package looks up the relevant form at runtime. It is not secret and does not grant access by itself.

## `NF_Submission_Log_Key__c.Key_Version__c`

The field name includes `Key`, so the analyzer reports it as a possible auth token.

This field stores a version label for submission-log cryptography configuration, such as `v2`. It is metadata about the key format/version only. It does not contain key material.

## `NF_Submission_Log_Key__c.Public_Key__c`

The field name includes `Public_Key`, so the analyzer reports it as possible sensitive data.

This field stores a public cryptographic key. Public keys are designed to be shared and are not secret. This field does not contain private key material.

## `NativeForms_Config__c.Captcha_Site_Key__c`

The field name includes `Key`, so the analyzer reports it as possible sensitive data.

This field stores a Google reCAPTCHA site key. A reCAPTCHA site key is intentionally public and is rendered in browser pages. The CAPTCHA secret key is not stored in Salesforce.

## `NativeForms_Config__c.Enable_Pro_SF_Secret_Code_Auth__c`

The field name includes `Secret`, so the analyzer reports it as possible sensitive data.

This field is a Boolean feature flag. It stores only `true` or `false`. The phrase `Secret Code` is the name of a product feature and does not mean the field contains a secret value.
