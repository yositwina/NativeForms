List<NF_Form_Action__c> actionsToUpdate = [
    SELECT Id, Config_JSON__c
    FROM NF_Form_Action__c
    WHERE Action_Scope__c = 'Submit'
      AND Command_Type__c = 'upsertMany'
      AND Object_Api_Name__c = 'Case'
      AND Form_Version__r.Form__r.Name = 'FORM-0007'
      AND Form_Version__r.Name = 'VER-0098'
];
if (actionsToUpdate.isEmpty()) {
    actionsToUpdate = [
        SELECT Id, Config_JSON__c
        FROM NF_Form_Action__c
        WHERE Action_Scope__c = 'Submit'
          AND Command_Type__c = 'upsertMany'
          AND Object_Api_Name__c = 'Case'
          AND Form_Version__r.Form__r.Name = 'FORM-0007'
    ];
}
for (NF_Form_Action__c row : actionsToUpdate) {
    Map<String, Object> config = String.isBlank(row.Config_JSON__c)
        ? new Map<String, Object>()
        : (Map<String, Object>) JSON.deserializeUntyped(row.Config_JSON__c);
    config.put('relationshipField', 'ContactId');
    config.put('relationshipValueSource', 'field');
    config.put('relationshipValueText', 'ContactId');
    row.Config_JSON__c = JSON.serializePretty(config);
}
update actionsToUpdate;
System.debug('Updated submit actions: ' + actionsToUpdate.size());
