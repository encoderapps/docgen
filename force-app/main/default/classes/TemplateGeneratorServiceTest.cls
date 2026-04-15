@isTest
public class TemplateGeneratorServiceTest {

    @isTest
    static void testGenerateFromJunction() {

        // Step 1: Create Template
        Template__c temp = new Template__c(
            HTML_Structure__c = '<html></html>'
        );
        insert temp;

        // Step 2: JSON Config
        String jsonConfig = JSON.serialize(new Map<String, Object>{
            'objectName' => 'Account',
            'fields' => new List<Object>{
                new Map<String, Object>{
                    'type' => 'STRING',
                    'label' => 'Account Name',
                    'apiName' => 'Name'
                },
                new Map<String, Object>{
                    'type' => 'REFERENCE',
                    'label' => 'Owner',
                    'relationshipName' => 'Owner',
                    'fields' => new List<Object>{
                        new Map<String, Object>{
                            'apiName' => 'Name'
                        }
                    }
                }
            }
        });

        // ✅ Step 3: Correct Object (Mapping_Config__c)
        Mapping_Config__c mapping = new Mapping_Config__c(
            JSON_Structure__c = jsonConfig
        );
        insert mapping;

        // Step 4: Junction Object
        Template_mapping_output__c junction = new Template_mapping_output__c(
            Template_Id__c = temp.Id,
            Field_Mapping__c = mapping.Id   // ⚠️ this field still points to Mapping_Config__c
        );
        insert junction;

        Test.startTest();

        // Step 5: Call method
        TemplateGeneratorService.TemplateResult result =
            TemplateGeneratorService.generateFromJunction(junction.Id);

        Test.stopTest();

        // Step 6: Assertions
        System.assertEquals(true, result.success, 'Should be successful');
        System.assertEquals('Account', result.objectName);
        System.assertNotEquals(null, result.htmlTemplate);

        System.assert(result.htmlTemplate.contains('Account.Name'));
        System.assert(result.htmlTemplate.contains('Owner.Name'));

        // Step 7: Verify DB update
        Template_mapping_output__c updated = [
            SELECT Output_Html__c
            FROM Template_mapping_output__c
            WHERE Id = :junction.Id
        ];

        System.assertNotEquals(null, updated.Output_Html__c);
    }


    @isTest
    static void testGenerateFromJunction_Exception() {

        Account acc = New Account(Name = 'DocGen Account');
        insert acc;
        
        Test.startTest();

        TemplateGeneratorService.TemplateResult result =
            TemplateGeneratorService.generateFromJunction(acc.Id);

        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertNotEquals(null, result.errorMessage);
    }
}