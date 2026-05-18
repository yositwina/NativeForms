String secretB64 = NativeFormsBootstrapV2Signer.getOrCreateSigningSecretForBootstrapV2();
String fingerprint = EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(secretB64))).toLowerCase();
System.debug('BOOTSTRAP_V2_SECRET_B64_SHA256=' + fingerprint);
