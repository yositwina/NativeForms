String orgId = UserInfo.getOrganizationId().substring(0, 15);
String path = '/tenant/auth-health';
HttpRequest request = new HttpRequest();
request.setMethod('GET');
request.setEndpoint('callout:' + NativeFormsAwsClient.namedCredentialName() + path + '?orgId=' + EncodingUtil.urlEncode(orgId, 'UTF-8'));
NativeFormsAwsClient.applyBootstrapV2Signature(request, 'GET', path, '');
request.setTimeout(120000);

HttpResponse response = new Http().send(request);
System.debug('AUTH_HEALTH_STATUS=' + response.getStatusCode());
System.debug('AUTH_HEALTH_BODY=' + response.getBody());
