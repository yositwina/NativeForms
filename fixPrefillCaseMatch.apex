List<NF_Form_Action__c> actionsToUpdate = [
    SELECT Id, Config_JSON__c, Store_Result_As__c, Object_Api_Name__c, Command_Key__c
    FROM NF_Form_Action__c
    WHERE Action_Scope__c = 'Prefill'
      AND Store_Result_As__c = 'foundCases1'
      AND Object_Api_Name__c = 'Case'
];
for (NF_Form_Action__c row : actionsToUpdate) {
    row.Config_JSON__c = JSON.serializePretty(new Map<String, Object>{
        'where' => 'ContactId = {foundContact1.Id}',
        'conditions' => new List<Object>{
            new Map<String, Object>{
                'fieldApiName' => 'ContactId',
                'operator' => 'eq',
                'valueSource' => 'alias',
                'valueText' => 'foundContact1.Id'
            }
        },
        'conditionLogic' => '1',
        'conditionExpression' => '1',
        'onNotFound' => 'ignore',
        'orderBy' => 'CreatedDate DESC',
        'limit' => 25
    });
}
update actionsToUpdate;
System.debug('Updated actions: ' + actionsToUpdate.size());
