try {
    NF_Form_Version__c versionRow = [
        SELECT Id, Form__r.Name, Form__r.NF_Key__c, Name
        FROM NF_Form_Version__c
        WHERE Form__r.NF_Key__c = 'DEMO_CONTACT_UPDATE'
          AND Version_Number__c = 1
        LIMIT 1
    ];
    NativeFormsPublisher.PublishResult result = NativeFormsPublisher.publishVersion(versionRow.Id);
    System.debug('RESULT=' + JSON.serialize(result));
} catch (Exception e) {
    System.debug('ERR=' + e.getTypeName() + ' | ' + e.getMessage());
    System.debug('STACK=' + e.getStackTraceString());
}
