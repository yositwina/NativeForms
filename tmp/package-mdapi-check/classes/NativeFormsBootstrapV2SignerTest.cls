@IsTest
private class NativeFormsBootstrapV2SignerTest {
    @IsTest
    static void getOrCreateSigningSecretPersistsProtectedOrgSecret() {
        Test.startTest();
        String firstSecret = NativeFormsBootstrapV2Signer.getOrCreateSigningSecretB64();
        String secondSecret = NativeFormsBootstrapV2Signer.getOrCreateSigningSecretB64();
        Test.stopTest();

        System.assert(String.isNotBlank(firstSecret), 'Bootstrap V2 signing secret should be generated.');
        System.assertEquals(firstSecret, secondSecret, 'Bootstrap V2 signing secret should be reused after creation.');
        System.assertEquals(32, EncodingUtil.base64Decode(firstSecret).size(), 'Bootstrap V2 signing secret should be 256 bits.');

        NativeForms_Protected_Config__c config = NativeForms_Protected_Config__c.getOrgDefaults();
        System.assertEquals(firstSecret, config.Bootstrap_V2_Signing_Secret__c, 'Secret should be stored in protected org defaults.');
    }

    @IsTest
    static void signForSpikeBuildsExpectedCanonicalSignature() {
        String body = '{"message":"hello bootstrap v2"}';
        NativeFormsBootstrapV2Signer.getOrCreateSigningSecretB64();

        Test.startTest();
        NativeFormsBootstrapV2Signer.SignedRequest signed = NativeFormsBootstrapV2Signer.signForSpike(
            'post',
            'tenant/bootstrap-v2/verify-signed-call',
            body
        );
        Test.stopTest();

        System.assertEquals('POST', signed.method);
        System.assertEquals('/tenant/bootstrap-v2/verify-signed-call', signed.path);
        System.assertEquals(normalizeOrgId(UserInfo.getOrganizationId()), signed.orgId);
        System.assertEquals(NativeFormsBootstrapV2Signer.SIGNATURE_ALGORITHM, signed.algorithm);
        System.assertEquals(NativeFormsBootstrapV2Signer.sha256Hex(body), signed.bodyHash);
        System.assert(String.isNotBlank(signed.timestamp), 'Signed request should include a timestamp.');
        System.assert(String.isNotBlank(signed.nonce), 'Signed request should include a nonce.');

        String canonical = NativeFormsBootstrapV2Signer.buildCanonicalString(
            signed.method,
            signed.path,
            signed.orgId,
            signed.timestamp,
            signed.nonce,
            signed.bodyHash
        );
        String expectedSignature = NativeFormsBootstrapV2Signer.hmacBase64(
            canonical,
            NativeFormsBootstrapV2Signer.getOrCreateSigningSecretB64()
        );
        System.assertEquals(expectedSignature, signed.signature, 'Signed request should use the documented canonical string.');
    }

    @IsTest
    static void buildSignedHeadersReturnsExpectedHeaderNames() {
        NativeFormsBootstrapV2Signer.getOrCreateSigningSecretB64();

        Map<String, String> headers = NativeFormsBootstrapV2Signer.buildSignedHeaders(
            'POST',
            '/tenant/bootstrap-v2/verify-signed-call',
            '{}'
        );

        System.assertEquals(normalizeOrgId(UserInfo.getOrganizationId()), headers.get('x-twinaforms-org-id'));
        System.assertEquals(NativeFormsBootstrapV2Signer.SIGNATURE_ALGORITHM, headers.get('x-twinaforms-bootstrap-v2-algorithm'));
        System.assert(String.isNotBlank(headers.get('x-twinaforms-bootstrap-v2-timestamp')));
        System.assert(String.isNotBlank(headers.get('x-twinaforms-bootstrap-v2-nonce')));
        System.assert(String.isNotBlank(headers.get('x-twinaforms-bootstrap-v2-body-sha256')));
        System.assert(String.isNotBlank(headers.get('x-twinaforms-bootstrap-v2-signature')));
    }

    private static String normalizeOrgId(String orgId) {
        String normalized = String.isBlank(orgId) ? '' : orgId.trim();
        return normalized.length() >= 15 ? normalized.substring(0, 15) : normalized;
    }
}
