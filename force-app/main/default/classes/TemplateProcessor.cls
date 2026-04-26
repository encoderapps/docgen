/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 04-22-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class TemplateProcessor {

    @AuraEnabled
    public static Id generateHtmlFromTemplate(Id accountId, Id templateId, Id mappingId) {

        try {

            if (accountId == null || templateId == null || mappingId == null) {
                throw new AuraHandledException('Please select all fields');
            }
            String html = [
                SELECT HTML_Structure__c
                FROM Template__c
                WHERE Id = :templateId
                LIMIT 1
            ].HTML_Structure__c;

            if (String.isBlank(html)) {
                throw new AuraHandledException('Template HTML is empty');
            }

            Map<String, Set<String>> objectFieldsMap = new Map<String, Set<String>>();

            Matcher m = Pattern.compile('\\{!([a-zA-Z0-9_]+)\\.([a-zA-Z0-9_]+)\\}').matcher(html);

            while (m.find()) {
                String obj = m.group(1);
                String field = m.group(2);

                if (!objectFieldsMap.containsKey(obj)) {
                    objectFieldsMap.put(obj, new Set<String>());
                }

                objectFieldsMap.get(obj).add(field);
            }

            
            for (String objName : objectFieldsMap.keySet()) {

                if (objName == 'Account') {

                    html = mergeParentObjectData(
                        html,
                        objName,
                        accountId,
                        objectFieldsMap.get(objName)
                    );

                } else {

                    html = mergeChildObjectData(
                        html,
                        objName,
                        accountId,
                        objectFieldsMap.get(objName)
                    );
                }
            }

            Template_Mapping_Output__c rec = new Template_Mapping_Output__c();

            rec.Account__c = accountId;
            rec.Master_Record_Id__c = String.valueOf(accountId);
            rec.Template_Id__c = templateId;
            rec.Field_Mapping__c = mappingId;
            rec.Output_Html__c = html;

            insert rec;

            return rec.Id;

        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }

    
    private static String mergeParentObjectData(
        String html,
        String objectApiName,
        Id recordId,
        Set<String> fields
    ) {

        fields.add('Id');

        String query = 'SELECT ' + String.join(new List<String>(fields), ',') +
                       ' FROM ' + objectApiName +
                       ' WHERE Id = :recordId LIMIT 1';

        SObject sobj = Database.query(query);

        for (String fieldName : fields) {
            Object val = sobj.get(fieldName);

            html = html.replace(
                '{!' + objectApiName + '.' + fieldName + '}',
                val != null ? String.valueOf(val) : ''
            );
        }

        return html;
    }

    
    private static String mergeChildObjectData(
        String html,
        String objectApiName,
        Id accountId,
        Set<String> fields
    ) {

        fields.add('Id');

        String relationshipField = 'AccountId';

        String query = 'SELECT ' + String.join(new List<String>(fields), ',') +
                       ' FROM ' + objectApiName +
                       ' WHERE ' + relationshipField + ' = :accountId LIMIT 1';

        List<SObject> records = Database.query(query);

        if (!records.isEmpty()) {

            SObject sobj = records[0];

            for (String fieldName : fields) {
                Object val = sobj.get(fieldName);

                html = html.replace(
                    '{!' + objectApiName + '.' + fieldName + '}',
                    val != null ? String.valueOf(val) : ''
                );
            }

        } else {

            try {
                html = html.replaceAll(
                    '(?s)' + objectApiName + ' Details.*?<table>.*?</table>',
                    ''
                );
                
            } catch (Exception e) {}
        }

        return html;
    }
}