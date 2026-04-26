global class BulkDataProcessingBatch 
implements Database.Batchable<SObject>, Database.AllowsCallouts {

    private Id templateId;
    private String objectApiName;
    private String htmlTemplate;

    global BulkDataProcessingBatch(Id templateId, String objectApiName) {
        this.templateId = templateId;
        this.objectApiName = objectApiName;

        this.htmlTemplate = [
            SELECT Output_Html__c 
            FROM Template_Mapping_Output__c 
            WHERE Template_Id__c = :templateId 
            LIMIT 1
        ].Output_Html__c;
    }

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator('SELECT Id, Name FROM ' + objectApiName);
    }

    global void execute(Database.BatchableContext bc, List<SObject> scope) {

        Pattern pattern = Pattern.compile('\\{!([a-zA-Z0-9_\\.]+)\\}');

        List<ContentVersion> contentVersions = new List<ContentVersion>();
        List<ContentDocumentLink> links = new List<ContentDocumentLink>();

        for (SObject rec : scope) {

            Matcher m = pattern.matcher(htmlTemplate);
            String finalHtml = htmlTemplate;

            while (m.find()) {
                String fieldName = m.group(1);
                try {
                    Object value = rec.get(fieldName);
                    if (value != null) {
                        finalHtml = finalHtml.replace('{!' + fieldName + '}', String.valueOf(value));
                    }
                } catch (Exception e) {
                    System.debug('Field not found: ' + fieldName);
                }
            }

            // ⚠️ 1 callout per record (keep batch size small)
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://30enk4je0l.execute-api.ap-south-1.amazonaws.com/generate-pdf');
            req.setMethod('POST');
            req.setTimeout(120000);
            req.setHeader('Content-Type', 'application/json');

            req.setBody(JSON.serialize(new Map<String, Object>{
                'templateId'    => templateId,
                'htmlBody'      => finalHtml,
                'processedTime' => System.now()
            }));

            HttpResponse res = new Http().send(req);

            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {

                Map<String, Object> responseMap =
                    (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

                String pdfUrl = (String) responseMap.get('url');

                // ✅ Create file (store URL as content)
                ContentVersion cv = new ContentVersion();
                cv.Title = 'Generated PDF - ' + rec.get('Name');
                cv.PathOnClient = 'GeneratedPDF_' + rec.get('Id') + '.txt';
                cv.VersionData = Blob.valueOf('PDF URL: ' + pdfUrl);

                contentVersions.add(cv);

            } else {
                System.debug('API Failed for record: ' + rec.get('Id'));
            }
        }

        // ✅ Insert all files in bulk
        if (!contentVersions.isEmpty()) {
            insert contentVersions;

            // Fetch ContentDocumentIds in bulk
            Map<Id, ContentVersion> cvMap = new Map<Id, ContentVersion>(
                [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN :contentVersions]
            );

            Integer index = 0;

            for (SObject rec : scope) {
                if (index < contentVersions.size()) {

                    ContentDocumentLink cdl = new ContentDocumentLink();
                    cdl.ContentDocumentId = cvMap.get(contentVersions[index].Id).ContentDocumentId;
                    cdl.LinkedEntityId = rec.Id;
                    cdl.ShareType = 'V';

                    links.add(cdl);
                }
                index++;
            }

            if (!links.isEmpty()) {
                insert links;
            }
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('Bulk Data Processing Completed for Template: ' + templateId);
    }
}
