NF_Form_Version__c versionRow = [SELECT Id FROM NF_Form_Version__c WHERE Form__r.Name = 'FORM-0007' AND Version_Number__c = 1 LIMIT 1];
for (NF_Form_Element__c row : [SELECT Field_Key__c, Label__c, Element_Type__c FROM NF_Form_Element__c WHERE Form_Version__c = :versionRow.Id ORDER BY Order__c]) {
    System.debug(row.Element_Type__c + ' | ' + row.Label__c + ' | ' + row.Field_Key__c);
}
for (NF_Form_Action__c row : [SELECT Id, Config_JSON__c FROM NF_Form_Action__c WHERE Form_Version__c = :versionRow.Id AND Action_Scope__c = 'Submit']) {
    System.debug('ACTION=' + row.Config_JSON__c);
}
