# Global OAuth Settings

For the **associated** External Client App model, the global OAuth settings stay on the non-ephemeral source org and are **not packaged**.

This follows Salesforce guidance for associated packageable External Client Apps:
- package the external client app header
- package the OAuth settings file
- keep the global OAuth settings file on the source org that owns the consumer credentials

Current source org callback URL:
- `https://f4apx2tkemgn5i2vagzhboeyjm0nnnjh.lambda-url.eu-north-1.on.aws/oauth/callback`

If NativeForms later moves to a disassociated model, this folder will hold:
- `*.ecaGlblOauth-meta.xml`
