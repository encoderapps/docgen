public with sharing class HTMLContentController {

    @AuraEnabled(cacheable=true)
    public static String getHtmlContent(Id recordId) {
        Template_Mapping_Object__c rec = [
            SELECT Output_HTML_2__c
            FROM Template_Mapping_Object__c
            WHERE Id = :recordId 
            LIMIT 1
        ];
        return rec.Output_HTML_2__c;
    }

    @AuraEnabled
    public static void saveHtmlContent(Id recordId, String updatedHtml) {
        Template_Mapping_Object__c rec = new Template_Mapping_Object__c(
            Id = recordId,
            Output_HTML_2__c = updatedHtml
        );
        update rec;
    }
}