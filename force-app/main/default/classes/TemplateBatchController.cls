/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 04-17-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class TemplateBatchController {

    @AuraEnabled(cacheable=true)
    public static List<Template__c> getTemplates() {
        return [
            SELECT Id, Name
            FROM Template__c
            ORDER BY Name
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getAllObjects() {

        List<String> objectNames = new List<String>();
        Map<String, Schema.SObjectType> objMap = Schema.getGlobalDescribe();

        for (String objName : objMap.keySet()) {
            if (objMap.get(objName).getDescribe().isQueryable()) {
                objectNames.add(objName);
            }
        }

        objectNames.sort();
        return objectNames;
    }

    
    @AuraEnabled
    public static String runBatch(Id templateId, String objectName) {

        if (templateId == null || String.isBlank(objectName)) {
            throw new AuraHandledException('Please select Template and Object');
        }

        if (!Schema.getGlobalDescribe().containsKey(objectName)) {
            throw new AuraHandledException('Invalid Object Selected');
        }

        
        Id jobId = Database.executeBatch(
            new BulkDataProcessingBatch(templateId, objectName),
            2000
        );

        return jobId;
    }
}

