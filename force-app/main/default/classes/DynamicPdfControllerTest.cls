@isTest
public class DynamicPdfControllerTest {

    @testSetup
    static void setupData() {

        Template__c temp = new Template__c(Name = 'Sample Template');
        insert temp;

        Template_Mapping_Output__c mapping = new Template_Mapping_Output__c(
            Template_ID__c = temp.Id,
            Output_HTML__c = '<div>{!Name}</div>'
        );
        insert mapping;

        Account acc = new Account(
            Name = 'Test Account',
            Phone = '1234567890',
            Industry = 'IT'
        );
        insert acc;

        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'test@example.com',
            AccountId = acc.Id
        );
        insert con;
    }

    @isTest
    static void testGetTemplateByName() {

        Test.startTest();
        String result = DynamicPdfController.getTemplateByName('Sample Template');
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.contains('{!Name}'));
    }

    @isTest
    static void testFetchDynamicRecord() {

        Account acc = [SELECT Id FROM Account LIMIT 1];

        List<String> fields = new List<String>{
            'Account.Name',
            'Account.Phone'
        };

        Test.startTest();
        Map<String, String> result = DynamicPdfController.fetchDynamicRecord(
            'Account',
            acc.Id,
            fields
        );
        Test.stopTest();

        System.assert(result.containsKey('Account.Name'));
        System.assert(result.containsKey('Account.Phone'));
    }

    @isTest
    static void testUpdateDynamicRecord() {

        Account acc = [SELECT Id FROM Account LIMIT 1];

        Map<String, String> updateMap = new Map<String, String>{
            'Account.Name' => 'Updated Name'
        };

        Test.startTest();
        DynamicPdfController.updateDynamicRecord(
            'Account',
            acc.Id,
            updateMap
        );
        Test.stopTest();

        Account updated = [SELECT Name FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Updated Name', updated.Name);
    }

    @isTest
    static void testGenerateDocument() {

        Account acc = [SELECT Id FROM Account LIMIT 1];

   
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Test.startTest();
        String url = DynamicPdfController.generateDocument(
            acc.Id,
            'Account',
            '<div>Test</div>'
        );
        Test.stopTest();

        System.assertNotEquals(null, url);
        System.assert(url.contains('http'));
    }


    class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            res.setBody('{"message":"PDF generated","file_url":"https://test.com/file.pdf"}');

            return res;
        }
    }
}