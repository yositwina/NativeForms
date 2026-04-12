for (NF_Form_Action__c row : [
    SELECT Id, Form_Version__r.Name, Form_Version__r.Form__r.Name, Store_Result_As__c, Object_Api_Name__c, Command_Key__c, Config_JSON__c
    FROM NF_Form_Action__c
    WHERE Action_Scope__c = 'Prefill'
    ORDER BY LastModifiedDate DESC
    LIMIT 20
]) {
    System.debug(row.Form_Version__r.Form__r.Name + ' | ' + row.Form_Version__r.Name + ' | ' + row.Store_Result_As__c + ' | ' + row.Object_Api_Name__c + ' | ' + row.Command_Key__c + ' | ' + row.Config_JSON__c);
}
