# NativeForms External Credentials

NativeForms uses the same deployable metadata pattern proven in FormCase:

- `NativeFormsBootstrap`
  - label: `NativeForms Bootstrap`
  - named principal: `NativeFormsBootstrapPrincipal`
  - auth variant: `NoAuthentication`
- `NativeFormsLambdaAuth`
  - label: `NativeFormsLambdaAuth`
  - named principal: `NativeFormsSharedSecret`

These API names are referenced by the packaged named credential metadata.
