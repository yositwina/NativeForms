trigger NFProjectTrigger on NF_Project__c (before insert, before update, before delete) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            NativeFormsProjectService.validateNames(Trigger.new, Trigger.isUpdate ? Trigger.oldMap : null);
        }
        if (Trigger.isDelete) {
            NativeFormsProjectService.blockDeleteWhenFormsExist(Trigger.old);
        }
    }
}
