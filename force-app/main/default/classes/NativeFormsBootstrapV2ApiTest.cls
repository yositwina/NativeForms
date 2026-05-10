@IsTest
private class NativeFormsBootstrapV2ApiTest {
    @IsTest
    static void returnsSigningSecretForAuthenticatedOrg() {
        NativeFormsBootstrapV2Api.ResponsePayload response = invoke(new Map<String, Object>{
            'orgId' => UserInfo.getOrganizationId().substring(0, 15),
            'purpose' => 'phase-2-spike'
        });

        System.assertEquals(true, response.success, 'Matching org should receive a Bootstrap V2 response.');
        System.assertEquals(true, response.experimental, 'Response should be marked experimental.');
        System.assertEquals(UserInfo.getOrganizationId().substring(0, 15), response.orgId);
        System.assertEquals(NativeFormsBootstrapV2Signer.SIGNATURE_ALGORITHM, response.algorithm);
        System.assertEquals(32, EncodingUtil.base64Decode(response.signingSecretB64).size(), 'Returned secret should be 256 bits.');
    }

    @IsTest
    static void rejectsMissingOrgId() {
        NativeFormsBootstrapV2Api.ResponsePayload response = invoke(new Map<String, Object>{
            'purpose' => 'phase-2-spike'
        });

        System.assertEquals(false, response.success, 'Missing org id should fail.');
        System.assertEquals('Missing required field: orgId', response.message);
        System.assertEquals(400, RestContext.response.statusCode);
    }

    @IsTest
    static void rejectsMismatchedOrgId() {
        NativeFormsBootstrapV2Api.ResponsePayload response = invoke(new Map<String, Object>{
            'orgId' => '00D000000000000',
            'purpose' => 'phase-2-spike'
        });

        System.assertEquals(false, response.success, 'Mismatched org id should fail.');
        System.assertEquals('Requested org does not match the authenticated org.', response.message);
        System.assertEquals(403, RestContext.response.statusCode);
    }

    private static NativeFormsBootstrapV2Api.ResponsePayload invoke(Map<String, Object> payload) {
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/nativeforms/bootstrap-v2/signing-secret';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(JSON.serialize(payload == null ? new Map<String, Object>() : payload));

        RestContext.request = request;
        RestContext.response = new RestResponse();

        return NativeFormsBootstrapV2Api.handlePost();
    }
}
