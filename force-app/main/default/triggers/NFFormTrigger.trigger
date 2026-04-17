trigger NFFormTrigger on NF_Form__c (before insert, before update) {
    if (Trigger.isBefore) {
        NativeFormsFormKeyService.validateDescriptions(Trigger.new);
        if (Trigger.isInsert) {
            NativeFormsFormKeyService.assignAutoKeys(Trigger.new);
        }
    }
}
