public without sharing class NativeFormsBootstrapV2Signer {
    public static final String SIGNATURE_ALGORITHM = 'HMAC-SHA256';
    private static final String APEX_HMAC_ALGORITHM = 'HmacSHA256';

    public class SignedRequest {
        public String method;
        public String path;
        public String orgId;
        public String timestamp;
        public String nonce;
        public String body;
        public String bodyHash;
        public String signature;
        public String algorithm;
    }

    public static SignedRequest signForSpike(String method, String path, String body) {
        String normalizedMethod = normalizeMethod(method);
        String normalizedPath = normalizePath(path);
        String normalizedBody = body == null ? '' : body;
        String orgId = normalizeOrgId(UserInfo.getOrganizationId());
        String timestamp = System.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
        String nonce = generateNonce();
        String bodyHash = sha256Hex(normalizedBody);
        String canonical = buildCanonicalString(
            normalizedMethod,
            normalizedPath,
            orgId,
            timestamp,
            nonce,
            bodyHash
        );

        SignedRequest signed = new SignedRequest();
        signed.method = normalizedMethod;
        signed.path = normalizedPath;
        signed.orgId = orgId;
        signed.timestamp = timestamp;
        signed.nonce = nonce;
        signed.body = normalizedBody;
        signed.bodyHash = bodyHash;
        signed.signature = hmacBase64(canonical, getSigningSecretB64());
        signed.algorithm = SIGNATURE_ALGORITHM;
        return signed;
    }

    public static Map<String, String> buildSignedHeaders(String method, String path, String body) {
        SignedRequest signed = signForSpike(method, path, body);
        return new Map<String, String>{
            'x-twinaforms-org-id' => signed.orgId,
            'x-twinaforms-bootstrap-v2-timestamp' => signed.timestamp,
            'x-twinaforms-bootstrap-v2-nonce' => signed.nonce,
            'x-twinaforms-bootstrap-v2-body-sha256' => signed.bodyHash,
            'x-twinaforms-bootstrap-v2-signature' => signed.signature,
            'x-twinaforms-bootstrap-v2-algorithm' => signed.algorithm
        };
    }

    public static String getOrCreateSigningSecretForBootstrapV2() {
        return getOrCreateSigningSecretB64();
    }

    @TestVisible
    static String getOrCreateSigningSecretB64() {
        NativeForms_Protected_Config__c config = NativeForms_Protected_Config__c.getOrgDefaults();
        if (config != null && String.isNotBlank(config.Bootstrap_V2_Signing_Secret__c)) {
            return config.Bootstrap_V2_Signing_Secret__c;
        }

        Blob secret = Crypto.generateAesKey(256);
        if (config == null) {
            config = new NativeForms_Protected_Config__c();
        }
        config.SetupOwnerId = UserInfo.getOrganizationId();
        config.Bootstrap_V2_Signing_Secret__c = EncodingUtil.base64Encode(secret);
        if (config.Id == null) {
            insert config;
        } else {
            update config;
        }
        return config.Bootstrap_V2_Signing_Secret__c;
    }

    @TestVisible
    static String getSigningSecretB64() {
        NativeForms_Protected_Config__c config = NativeForms_Protected_Config__c.getOrgDefaults();
        if (config != null && String.isNotBlank(config.Bootstrap_V2_Signing_Secret__c)) {
            return config.Bootstrap_V2_Signing_Secret__c;
        }
        throw new AuraHandledException('TwinaForms secure service access is not ready yet. Reconnect TwinaForms and try again.');
    }

    @TestVisible
    static String buildCanonicalString(String method, String path, String orgId, String timestamp, String nonce, String bodyHash) {
        return String.join(new List<String>{
            normalizeMethod(method),
            normalizePath(path),
            String.valueOf(orgId),
            String.valueOf(timestamp),
            String.valueOf(nonce),
            String.valueOf(bodyHash).toLowerCase()
        }, '\n');
    }

    @TestVisible
    static String sha256Hex(String value) {
        return EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(value == null ? '' : value))).toLowerCase();
    }

    @TestVisible
    static String hmacBase64(String canonical, String secretB64) {
        return EncodingUtil.base64Encode(
            Crypto.generateMac(
                APEX_HMAC_ALGORITHM,
                Blob.valueOf(canonical == null ? '' : canonical),
                EncodingUtil.base64Decode(secretB64)
            )
        );
    }

    private static String normalizeMethod(String method) {
        String normalized = String.isBlank(method) ? 'POST' : method.trim().toUpperCase();
        return normalized;
    }

    private static String normalizePath(String path) {
        String normalized = String.isBlank(path) ? '/' : path.trim();
        return normalized.startsWith('/') ? normalized : '/' + normalized;
    }

    private static String normalizeOrgId(String orgId) {
        String normalized = String.isBlank(orgId) ? '' : orgId.trim();
        return normalized.length() >= 15 ? normalized.substring(0, 15) : normalized;
    }

    private static String generateNonce() {
        return EncodingUtil.convertToHex(Crypto.generateAesKey(128)).toLowerCase();
    }
}
