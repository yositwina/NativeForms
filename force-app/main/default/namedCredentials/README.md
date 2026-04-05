# NativeForms Named Credentials

This package uses two named credentials:

- `NativeForms_Bootstrap`
  Bootstrap setup endpoint for org registration and initial setup.
- `NativeForms`
  Main authenticated endpoint for publish and other secure NativeForms admin callouts.

Both point to the shared NativeForms AWS base URL and differ by external credential.
