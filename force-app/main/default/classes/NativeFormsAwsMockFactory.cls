@IsTest
public class NativeFormsAwsMockFactory {
    private class ResponseSpec {
        Integer statusCode;
        String statusText;
        String body;
        Map<String, String> headers;
    }

    public class RoutingMock implements HttpCalloutMock {
        private List<String> endpointFragments = new List<String>();
        private List<ResponseSpec> responseSpecs = new List<ResponseSpec>();

        public RoutingMock addJsonResponse(String endpointFragment, Integer statusCode, Object bodyValue) {
            ResponseSpec responseSpec = new ResponseSpec();
            responseSpec.statusCode = statusCode;
            responseSpec.statusText = statusCode >= 200 && statusCode < 300 ? 'OK' : 'ERROR';
            responseSpec.body = JSON.serialize(bodyValue);
            responseSpec.headers = new Map<String, String>{
                'Content-Type' => 'application/json'
            };
            endpointFragments.add(endpointFragment);
            responseSpecs.add(responseSpec);
            return this;
        }

        public HttpResponse respond(HttpRequest request) {
            String endpointValue = request == null ? null : request.getEndpoint();
            for (Integer indexValue = 0; indexValue < endpointFragments.size(); indexValue += 1) {
                if (endpointValue != null && endpointValue.contains(endpointFragments[indexValue])) {
                    return toHttpResponse(responseSpecs[indexValue]);
                }
            }

            ResponseSpec fallbackResponse = new ResponseSpec();
            fallbackResponse.statusCode = 500;
            fallbackResponse.statusText = 'NO MOCK';
            fallbackResponse.body = '{"success":false,"error":"No mock configured for endpoint."}';
            fallbackResponse.headers = new Map<String, String>{
                'Content-Type' => 'application/json'
            };
            return toHttpResponse(fallbackResponse);
        }

        private HttpResponse toHttpResponse(ResponseSpec responseSpec) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(responseSpec.statusCode);
            response.setStatus(responseSpec.statusText);
            response.setBody(responseSpec.body);
            if (responseSpec.headers != null) {
                for (String headerName : responseSpec.headers.keySet()) {
                    response.setHeader(headerName, responseSpec.headers.get(headerName));
                }
            }
            return response;
        }
    }

    public class ThrowingMock implements HttpCalloutMock {
        private String message;

        public ThrowingMock(String messageValue) {
            message = messageValue;
        }

        public HttpResponse respond(HttpRequest request) {
            throw new CalloutException(message);
        }
    }

    public static HttpCalloutMock entitlementsSuccess(Map<String, Object> featureFlags, Map<String, Object> limits, String planCode) {
        String orgId = UserInfo.getOrganizationId().substring(0, 15);
        return new RoutingMock().addJsonResponse(
            '/tenant/entitlements',
            200,
            new Map<String, Object>{
                'success' => true,
                'orgId' => orgId,
                'planCode' => String.isBlank(planCode) ? 'starter' : planCode,
                'effectiveFeatureFlags' => featureFlags == null ? new Map<String, Object>() : featureFlags,
                'effectiveLimits' => limits == null ? new Map<String, Object>() : limits
            }
        );
    }

    public static HttpCalloutMock entitlementsFailure(Integer statusCode, String errorMessage) {
        Integer safeStatusCode = statusCode == null ? 500 : statusCode;
        return new RoutingMock().addJsonResponse(
            '/tenant/entitlements',
            safeStatusCode,
            new Map<String, Object>{
                'success' => false,
                'error' => String.isBlank(errorMessage) ? 'Unable to load NativeForms entitlements.' : errorMessage
            }
        );
    }

    public static HttpCalloutMock throwingCallout(String message) {
        return new ThrowingMock(String.isBlank(message) ? 'Synthetic callout failure.' : message);
    }
}
