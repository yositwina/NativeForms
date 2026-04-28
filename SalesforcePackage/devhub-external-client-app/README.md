# Dev Hub External Client App Metadata

This folder tracks source-org External Client App metadata that is not part of the managed package.

Use it for the persistent TwinaForms Dev Hub/source org only. Do not move these policy/global settings files into `force-app`, because configurable policy and global OAuth settings are not packageable in the current TwinaForms 2GP flow.

Current policy intent:
- Refresh token policy: valid until revoked
- AWS refreshes Salesforce access tokens by using the tenant refresh token plus the central TwinaForms ECA client credentials
