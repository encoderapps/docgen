/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 04-12-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class TemplateGeneratorService {
   // public TemplateGeneratorService() {
            public class TemplateResult {
        @AuraEnabled public String objectName;
        @AuraEnabled public String htmlTemplate;
        @AuraEnabled public Boolean success;
        @AuraEnabled public String errorMessage;

        public TemplateResult() {
            this.success = true;
        }
    }

    @AuraEnabled
    public static TemplateResult generateFromJunction(String junctionId) {
        TemplateResult result = new TemplateResult();

        try {
            Template_mapping_output__c junction = [
                SELECT
                    Id,
                    Template_Id__r.HTML_Structure__c,
                    Field_Mapping__r.JSON_Structure__c
                FROM Template_mapping_output__c
                WHERE Id = :junctionId
                LIMIT 1
            ];

            Map<String, Object> config = (Map<String, Object>) JSON.deserializeUntyped(junction.Field_Mapping__r.JSON_Structure__c);
            String objectName          = (String) config.get('objectName');
            List<Object> fields        = (List<Object>) config.get('fields');

            List<String> lines = new List<String>();
            lines.add('<!DOCTYPE html>');
            lines.add('<html>');
            lines.add('<body>');
            lines.add('<table>');

            for (Object f : fields) {
                Map<String, Object> field  = (Map<String, Object>) f;
                String fieldType           = (String) field.get('type');
                String label               = (String) field.get('label');
                String apiName             = (String) field.get('apiName');
                String relationshipName    = (String) field.get('relationshipName');
                List<Object> subFields     = (List<Object>) field.get('fields');

                if (fieldType == 'REFERENCE' && subFields != null && !subFields.isEmpty() && String.isNotBlank(relationshipName)) {
                    for (Object sf : subFields) {
                        Map<String, Object> subField = (Map<String, Object>) sf;
                        String subApiName            = (String) subField.get('apiName');
                        lines.add('<tr>');
                        lines.add('  <td>' + label + ' - ' + subApiName + ' : {!' + objectName + '.' + relationshipName + '.' + subApiName + '}</td>');
                        lines.add('</tr>');
                    }
                } else {
                    lines.add('<tr>');
                    lines.add('  <td>' + label + ' : {!' + objectName + '.' + apiName + '}</td>');
                    lines.add('</tr>');
                }
            }

            lines.add('</table>');
            lines.add('</body>');
            lines.add('</html>');

            result.objectName   = objectName;
            result.htmlTemplate = String.join(lines, '\n');

            update new Template_mapping_output__c(
                Id             = junction.Id,
                Output_Html__c = result.htmlTemplate
            );

        } catch (Exception e) {
            result.success      = false;
            result.errorMessage = e.getMessage();
        }

        return result;
    }


    }