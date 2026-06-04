@IsTest
private class NativeFormsSecretCodeApiTest {
    @IsTest
    static void compatibilityClassDelegatesToUserVerificationApi() {
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/nativeforms/user-verification';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf('{}');
        RestContext.request = request;
        RestContext.response = new RestResponse();

        NativeFormsSecretCodeApi.ResponsePayload response = NativeFormsSecretCodeApi.handlePost();

        System.assertEquals(false, response.success, 'Compatibility class should delegate to the active User Verification API.');
        System.assertEquals('Missing required field: action', response.message, 'Validation should come from the active User Verification API.');
        System.assertEquals(400, RestContext.response.statusCode, 'Delegated validation should preserve status code.');
    }
}
