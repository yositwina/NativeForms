public with sharing class NativeFormsDemoDataController {
    @AuraEnabled(cacheable=true)
    public static NativeFormsDemoDataService.HomeSnapshot getHomeState() {
        return NativeFormsDemoDataService.getHomeSnapshot();
    }

    @AuraEnabled
    public static NativeFormsDemoDataService.InstallSummary installDemoData() {
        try {
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
}
