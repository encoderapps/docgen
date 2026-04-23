public with sharing class FieldMappingController {

    // ================= WRAPPER CLASSES =================

    public class FieldWrapper {
        @AuraEnabled public String label;
        @AuraEnabled public String apiName;
        @AuraEnabled public String type;
        @AuraEnabled public String referenceTo;
    }

    public class ObjectWrapper {
        @AuraEnabled public String label;
        @AuraEnabled public String apiName;
    }

    // 🔥 NEW WRAPPER FOR RELATED OBJECTS
    public class RelatedObjectWrapper {
        @AuraEnabled public String label;
        @AuraEnabled public String apiName;
    }

    // ================= GET ALL OBJECTS =================
    @AuraEnabled(cacheable=true)
    public static List<ObjectWrapper> getAllObjects() {

        List<ObjectWrapper> result = new List<ObjectWrapper>();
        Map<String, Schema.SObjectType> globalMap = Schema.getGlobalDescribe();

        for (String objName : globalMap.keySet()) {

            Schema.DescribeSObjectResult describe =
                globalMap.get(objName).getDescribe();

            if (
                !describe.isAccessible() ||
                !describe.isQueryable() ||
                describe.isDeprecatedAndHidden() ||
                describe.getLabel() == null ||
                describe.getLabel().contains('MISSING')
            ) {
                continue;
            }

            ObjectWrapper obj = new ObjectWrapper();
            obj.label = describe.getLabel();
            obj.apiName = objName;

            result.add(obj);
        }

        result.sort(new ObjectLabelSorter());
        return result;
    }

    // ================= GET OBJECT FIELDS =================
    @AuraEnabled(cacheable=true)
    public static List<FieldWrapper> getObjectFields(String objectName) {

        List<FieldWrapper> result = new List<FieldWrapper>();

        if (String.isBlank(objectName)) {
            return result;
        }

        Schema.SObjectType objType =
            Schema.getGlobalDescribe().get(objectName);

        if (objType == null) {
            return result;
        }

        Schema.DescribeSObjectResult describeResult =
            objType.getDescribe();

        Map<String, Schema.SObjectField> fieldMap =
            describeResult.fields.getMap();

        for (Schema.SObjectField field : fieldMap.values()) {

            Schema.DescribeFieldResult fd = field.getDescribe();

            if (!fd.isAccessible()) {
                continue;
            }

            FieldWrapper wrapper = new FieldWrapper();
            wrapper.label = fd.getLabel();
            wrapper.apiName = fd.getName();
            wrapper.type = String.valueOf(fd.getType());

            if (
                fd.getType() == Schema.DisplayType.REFERENCE &&
                !fd.getReferenceTo().isEmpty()
            ) {
                wrapper.referenceTo =
                    fd.getReferenceTo()[0].getDescribe().getName();
            }

            result.add(wrapper);
        }

        result.sort(new FieldWrapperSorter());
        return result;
    }

    // ================= GET RELATED OBJECTS (UPDATED) =================
    @AuraEnabled(cacheable=true)
    public static List<RelatedObjectWrapper> getRelatedObjects(String objectName) {

        List<RelatedObjectWrapper> relatedList = new List<RelatedObjectWrapper>();

        if (String.isBlank(objectName)) {
            return relatedList;
        }

        Schema.SObjectType objType =
            Schema.getGlobalDescribe().get(objectName);

        if (objType == null) {
            return relatedList;
        }

        Schema.DescribeSObjectResult describeResult =
            objType.getDescribe();

        for (Schema.ChildRelationship cr :
                describeResult.getChildRelationships()) {

            if (cr.getRelationshipName() == null) {
                continue;
            }

            Schema.SObjectType childType = cr.getChildSObject();

            if (childType != null) {

                Schema.DescribeSObjectResult childDescribe =
                    childType.getDescribe();

                if (
                    childDescribe.isAccessible() &&
                    childDescribe.isQueryable()
                ) {
                    RelatedObjectWrapper obj = new RelatedObjectWrapper();
                    obj.label = childDescribe.getLabel();   // ✅ LABEL
                    obj.apiName = childDescribe.getName();  // ✅ API

                    relatedList.add(obj);
                }
            }
        }

        relatedList.sort(new RelatedObjectSorter());
        return relatedList;
    }

    // ================= SORTERS =================

    public class FieldWrapperSorter
        implements Comparator<FieldWrapper> {

        public Integer compare(FieldWrapper a, FieldWrapper b) {
            return a.label.toLowerCase()
                .compareTo(b.label.toLowerCase());
        }
    }

    public class ObjectLabelSorter
        implements Comparator<ObjectWrapper> {

        public Integer compare(ObjectWrapper a, ObjectWrapper b) {
            return a.label.toLowerCase()
                .compareTo(b.label.toLowerCase());
        }
    }

    // 🔥 NEW SORTER
    public class RelatedObjectSorter
        implements Comparator<RelatedObjectWrapper> {

        public Integer compare(RelatedObjectWrapper a, RelatedObjectWrapper b) {
            return a.label.toLowerCase()
                .compareTo(b.label.toLowerCase());
        }
    }

    // ================= SAVE =================
    @AuraEnabled
    public static String saveMappingConfig(
        String objectName,
        String jsonData
    ) {

        if (String.isBlank(objectName)) {
            throw new AuraHandledException(
                'Source Object is required.'
            );
        }

        if (String.isBlank(jsonData)) {
            throw new AuraHandledException(
                'JSON is empty.'
            );
        }

        if (!Schema.sObjectType.Mapping_Config__c.isCreateable()) {
            throw new AuraHandledException(
                'No permission to create Mapping Config.'
            );
        }

        Mapping_Config__c record = new Mapping_Config__c();

        record.Name =
            objectName + '_Mapping_' +
            System.now().format('yyyyMMdd_HHmmss');

        record.Source_Object__c = objectName;
        record.JSON_Structure__c = jsonData;

        insert record;

        return record.Id;
    }
}