# TwinaForms External Credentials

TwinaForms uses deployable External Credential metadata for AWS callouts:

- `TwinaFormsBootstrap`
  - label: `TwinaForms Bootstrap`
  - named principal: `TwinaFormsBootstrapPrincipal`
  - auth variant: `NoAuthentication`
- `TwinaFormsLambdaAuth`
  - label: `TwinaForms Shared Secret`
  - named principal: `TwinaFormsSharedSecret`

These API names are referenced by the packaged named credential metadata.
