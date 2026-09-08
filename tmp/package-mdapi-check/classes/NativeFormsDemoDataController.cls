public with sharing class NativeFormsDemoDataController {
    @TestVisible private static Boolean forceInstallFailureForTest = false;

    @AuraEnabled(cacheable=true)
    public static NativeFormsDemoDataService.HomeSnapshot getHomeState() {
        return NativeFormsDemoDataService.getHomeSnapshot();
    }

    @AuraEnabled
    public static NativeFormsDemoDataService.InstallSummary installDemoData() {
        try {
            if (Test.isRunningTest() && forceInstallFailureForTest) {
                throw new IllegalArgumentException('Injected demo install failure.');
            }
            return NativeFormsDemoDataService.installDemoData();
        } catch (Exception e) {
            throw new AuraHandledException(formatException(e));
        }
    }

    private static String formatException(Exception e) {
        if (e == null) {
            return 'Unknown error';
        }
        List<String> parts = new List<String>();
        if (e.getMessage() != null) {
            parts.add(e.getMessage());
        }
        if (e.getCause() != null && e.getCause().getMessage() != null && e.getCause().getMessage() != e.getMessage()) {
            parts.add(e.getCause().getMessage());
        }
        return parts.isEmpty() ? 'Unknown error' : String.join(parts, ' | ');
    }

    @TestVisible
    private static String formatExceptionForTest(Exception e) {
        return formatException(e);
    }
}
