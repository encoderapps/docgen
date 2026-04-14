public with sharing class FieldMappingController {

    // ================= WRAPPER CLASS =================
    public class FieldWrapper {
        @AuraEnabled public String label;
        @AuraEnabled public String apiName;
        @AuraEnabled public String type;
        @AuraEnabled public String referenceTo;
    }

    // ================= GET ALL OBJECTS =================
    @AuraEnabled(cacheable=true)
    public static List<String> getAllObjects() {

        List<String> objectNames = new List<String>();
        Map<String, Schema.SObjectType> globalMap = Schema.getGlobalDescribe();

        for(String objName : globalMap.keySet()){
            objectNames.add(objName);
        }

        objectNames.sort();
        return objectNames;
    }

    // ================= GET OBJECT FIELDS =================
    @AuraEnabled(cacheable=true)
    public static List<FieldWrapper> getObjectFields(String objectName) {

        List<FieldWrapper> result = new List<FieldWrapper>();

        if(String.isBlank(objectName)){
            return result;
        }

        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);

        if(objType == null){
            return result;
        }

        Schema.DescribeSObjectResult describeResult = objType.getDescribe();
        Map<String, Schema.SObjectField> fieldMap = describeResult.fields.getMap();

        for(Schema.SObjectField field : fieldMap.values()){

            Schema.DescribeFieldResult fd = field.getDescribe();

            // Skip inaccessible fields
            if(!fd.isAccessible()){
                continue;
            }

            FieldWrapper wrapper = new FieldWrapper();
            wrapper.label = fd.getLabel();
            wrapper.apiName = fd.getName();
            wrapper.type = String.valueOf(fd.getType());

            // If lookup/master-detail, capture reference object
            if(fd.getType() == Schema.DisplayType.REFERENCE 
                && !fd.getReferenceTo().isEmpty()) {

                wrapper.referenceTo = fd.getReferenceTo()[0]
                    .getDescribe()
                    .getName();
            }

            result.add(wrapper);
        }

        result.sort(new FieldWrapperSorter());
        return result;
    }

    // ================= GET RELATED (CHILD) OBJECTS =================
    @AuraEnabled(cacheable=true)
    public static List<String> getRelatedObjects(String objectName){

        List<String> relatedList = new List<String>();

        if(String.isBlank(objectName)){
            return relatedList;
        }

        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);

        if(objType == null){
            return relatedList;
        }

        Schema.DescribeSObjectResult describeResult = objType.getDescribe();

        for(Schema.ChildRelationship cr : describeResult.getChildRelationships()){

            // Skip null relationship names
            if(cr.getRelationshipName() == null){
                continue;
            }

            Schema.SObjectType childType = cr.getChildSObject();

            if(childType != null){

                Schema.DescribeSObjectResult childDescribe = childType.getDescribe();

                // Only include accessible child objects
                if(childDescribe.isAccessible()){
                    relatedList.add(childDescribe.getName());
                }
            }
        }

        relatedList.sort();
        return relatedList;
    }

    // ================= SORTER =================
    public class FieldWrapperSorter implements Comparator<FieldWrapper> {
        public Integer compare(FieldWrapper a, FieldWrapper b) {
            return a.label.toLowerCase().compareTo(b.label.toLowerCase());
        }
    }

    // ================= SAVE MAPPING CONFIG =================
    @AuraEnabled
    public static String saveMappingConfig(String objectName, String jsonData) {

        if(String.isBlank(objectName)){
            throw new AuraHandledException('Source Object is required.');
        }

        if(String.isBlank(jsonData)){
            throw new AuraHandledException('JSON is empty.');
        }

        if(!Schema.sObjectType.Mapping_Config__c.isCreateable()){
            throw new AuraHandledException('No permission to create Mapping Config.');
        }

        Mapping_Config__c record = new Mapping_Config__c();

        record.Name = objectName + '_Mapping_' + 
              System.now().format('yyyyMMdd_HHmmss');

        record.Source_Object__c = objectName;
        record.JSON_Structure__c = jsonData;

        insert record;

        return record.Id;
    }
}
