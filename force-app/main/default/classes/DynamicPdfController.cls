public with sharing class DynamicPdfController {

    @AuraEnabled(cacheable=true)
    public static List<Template__c> getTemplateRecords() {
        return [
            SELECT Id, Name
            FROM Template__c
            ORDER BY Name
        ];
    }

    @AuraEnabled
    public static Map<String, String> getMappedHtml(Id recordId, Id templateId) {

        List<Template_Mapping_Output__c> mappings = [
            SELECT 
                Template_ID__c,
                Template_ID__r.HTML_Structure__c
            FROM Template_Mapping_Output__c
            WHERE Master_Record_Id__c = :recordId
            AND Template_ID__c = :templateId
            LIMIT 1
        ];

        if (mappings.isEmpty()) {
            throw new AuraHandledException('No "Template Mapping Output" found for this record.');
        }

        return new Map<String, String>{
            'structure' => mappings[0].Template_ID__r.HTML_Structure__c
        };
    }

    @AuraEnabled
    public static Map<String, String> fetchDynamicRecord(
        String objectApiName,
        Id recordId,
        List<String> fieldPaths
    ) {
        Map<String, String> result = new Map<String, String>();

        if (String.isBlank(objectApiName) || recordId == null || fieldPaths.isEmpty()) {
            return result;
        }

        Set<String> parentFields = new Set<String>();
        Set<String> childFields = new Set<String>();
        String childObjectName;

        for (String path : fieldPaths) {
            List<String> parts = path.split('\\.');

            if (parts.size() == 2 && parts[0] == objectApiName) {
                parentFields.add(parts[1]);
            }

            if (parts.size() == 3) {
                childObjectName = parts[1];
                childFields.add(parts[2]);
            }
        }

        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectApiName);
        Map<String, Schema.SObjectField> fieldMap = objType.getDescribe().fields.getMap();

        List<String> safeParentFields = new List<String>();

        for (String f : parentFields) {
            if (fieldMap.containsKey(f)) {
                safeParentFields.add(f);
            }
        }

        String childRelationshipName;

        if (!String.isBlank(childObjectName)) {
            for (Schema.ChildRelationship cr : objType.getDescribe().getChildRelationships()) {
                if (cr.getChildSObject().getDescribe().getName() == childObjectName) {
                    childRelationshipName = cr.getRelationshipName();
                    break;
                }
            }
        }

        String query = 'SELECT ' + String.join(safeParentFields, ',');

        if (!childFields.isEmpty() && childRelationshipName != null) {
            query += ', (SELECT ' + String.join(new List<String>(childFields), ',') +
                     ' FROM ' + childRelationshipName + ')';
        }

        query += ' FROM ' + objectApiName + ' WHERE Id = :recordId LIMIT 1';

        System.debug('Dynamic Query: ' + query);

        SObject record = Database.query(query);

        for (String f : safeParentFields) {
            Object val = record.get(f);
            result.put(objectApiName + '.' + f, val != null ? String.valueOf(val) : '');
        }

        if (!childFields.isEmpty() && childRelationshipName != null) {

            List<SObject> children = (List<SObject>) record.getSObjects(childRelationshipName);

            if (children != null && !children.isEmpty()) {

                SObject child = children[0];

                for (String f : childFields) {
                    Object val = child.get(f);
                    result.put(childObjectName + '.' + f, val != null ? String.valueOf(val) : '');
                }
            }
        }

        return result;
    }

    @AuraEnabled
    public static void updateDynamicRecord(
        String objectApiName,
        Id recordId,
        Map<String, String> fieldValues
    ) {
        if (String.isBlank(objectApiName) || recordId == null || fieldValues == null) {
            throw new AuraHandledException('Invalid input');
        }

        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectApiName);

        if (objType == null) {
            throw new AuraHandledException('Invalid object');
        }

        SObject record = objType.newSObject(recordId);

        Map<String, Schema.SObjectField> fieldMap = objType.getDescribe().fields.getMap();

        for (String key : fieldValues.keySet()) {

            List<String> parts = key.split('\\.');

            if (parts.size() == 2 && parts[0] == objectApiName) {
                String fieldName = parts[1];

                if (fieldMap.containsKey(fieldName)) {
                    record.put(fieldName, fieldValues.get(key));
                }
            }
        }

        update record;
    }

    @AuraEnabled
    public static String generateDocument(
        Id recordId,
        String objectApiName,
        String htmlContent
    ) {

        Map<String, Object> requestBody = new Map<String, Object>{
            'html' => htmlContent
        };

        String jsonBody = JSON.serialize(requestBody);

        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://30enk4je0l.execute-api.ap-south-1.amazonaws.com/generate-pdf');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(jsonBody);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('API Error: ' + res.getBody());
        }

        Map<String, Object> responseMap =
            (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        String fileUrl = (String) responseMap.get('file_url');

        if (recordId != null && String.isNotBlank(objectApiName)) {

            Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectApiName);

            if (objType == null) {
                throw new AuraHandledException('Invalid object');
            }

            SObject record = objType.newSObject(recordId);
            record.put('PDF_Link__c', fileUrl);

            update record;
        }

        return fileUrl;
    }
}