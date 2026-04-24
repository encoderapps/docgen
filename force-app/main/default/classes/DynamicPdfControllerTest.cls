@isTest
public class DynamicPdfControllerTest {

    @testSetup
    static void setupData() {
        Template__c temp = new Template__c(
            Name = 'Test Template',
            HTML_Structure__c = '<div>{!Account.Name}</div>'
        );
        insert temp;

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Template_Mapping_Output__c mapRec = new Template_Mapping_Output__c(
            Template_ID__c = temp.Id,
            Master_Record_Id__c = acc.Id
        );
        insert mapRec;
    }

    @isTest
    static void testGetTemplateRecords() {
        Test.startTest();
        List<Template__c> result = DynamicPdfController.getTemplateRecords();
        Test.stopTest();

        System.assert(!result.isEmpty(), 'Templates should be returned');
    }

    @isTest
    static void testGetMappedHtml() {
        Template__c temp = [SELECT Id FROM Template__c LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        Map<String, String> result = DynamicPdfController.getMappedHtml(acc.Id, temp.Id);
        Test.stopTest();

        System.assert(result.containsKey('structure'), 'Structure should exist');
    }

    @isTest
    static void testFetchDynamicRecord() {
        Account acc = [SELECT Id, Name FROM Account LIMIT 1];

        List<String> fields = new List<String>{
            'Account.Name'
        };

        Test.startTest();
        Map<String, String> result = DynamicPdfController.fetchDynamicRecord(
            'Account',
            acc.Id,
            fields
        );
        Test.stopTest();

        System.assertEquals('Test Account', result.get('Account.Name'));
    }

    @isTest
    static void testUpdateDynamicRecord() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Map<String, String> updates = new Map<String, String>{
            'Account.Name' => 'Updated Name'
        };

        Test.startTest();
        DynamicPdfController.updateDynamicRecord(
            'Account',
            acc.Id,
            updates
        );
        Test.stopTest();

        Account updated = [SELECT Name FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Updated Name', updated.Name);
    }

    @isTest
    static void testGenerateDocument() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());

        Test.startTest();
        String fileUrl = DynamicPdfController.generateDocument(
            acc.Id,
            'Account',
            '<h1>Test</h1>'
        );
        Test.stopTest();

        System.assertNotEquals(null, fileUrl);

        Account updated = [SELECT PDF_Link__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals(fileUrl, updated.PDF_Link__c);
    }

    class MockHttpResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"file_url":"https://test.com/sample.pdf"}');
            res.setStatusCode(200);
            return res;
        }
    }
}