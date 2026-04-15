@isTest
public class FieldMappingControllerTest {

    // ================= TEST GET ALL OBJECTS =================
    @isTest
    static void testGetAllObjects() {

        Test.startTest();
        List<String> objects = FieldMappingController.getAllObjects();
        Test.stopTest();

        System.assertNotEquals(null, objects, 'Object list should not be null');
        System.assert(objects.size() > 0, 'Object list should not be empty');
    }

    // ================= TEST GET OBJECT FIELDS =================
    @isTest
    static void testGetObjectFields() {

        Test.startTest();
        List<FieldMappingController.FieldWrapper> fields =
            FieldMappingController.getObjectFields('Account');
        Test.stopTest();

        System.assertNotEquals(null, fields);
        System.assert(fields.size() > 0);

        FieldMappingController.FieldWrapper f = fields[0];
        System.assertNotEquals(null, f.label);
        System.assertNotEquals(null, f.apiName);
    }

    // ================= TEST GET OBJECT FIELDS - INVALID =================
    @isTest
    static void testGetObjectFields_Invalid() {

        Test.startTest();
        List<FieldMappingController.FieldWrapper> fields =
            FieldMappingController.getObjectFields('');
        Test.stopTest();

        System.assertEquals(0, fields.size());
    }

    // ================= TEST GET RELATED OBJECTS =================
    @isTest
    static void testGetRelatedObjects() {

        Test.startTest();
        List<String> related =
            FieldMappingController.getRelatedObjects('Account');
        Test.stopTest();

        System.assertNotEquals(null, related);
    }

    // ================= TEST GET RELATED OBJECTS - INVALID =================
    @isTest
    static void testGetRelatedObjects_Invalid() {

        Test.startTest();
        List<String> related =
            FieldMappingController.getRelatedObjects('');
        Test.stopTest();

        System.assertEquals(0, related.size());
    }

    // ================= TEST SAVE MAPPING CONFIG =================
    @isTest
    static void testSaveMappingConfig() {

        String jsonData = '{"field":"Name"}';

        Test.startTest();
        String recordId = FieldMappingController.saveMappingConfig(
            'Account',
            jsonData
        );
        Test.stopTest();

        System.assertNotEquals(null, recordId);

        Mapping_Config__c rec = [
            SELECT Id, Source_Object__c, JSON_Structure__c
            FROM Mapping_Config__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        System.assertEquals('Account', rec.Source_Object__c);
        System.assertEquals(jsonData, rec.JSON_Structure__c);
    }

    // ================= TEST SAVE MAPPING CONFIG - NO OBJECT =================
    @isTest
    static void testSaveMappingConfig_NoObject() {

        Boolean exceptionThrown = false;

        try {
            FieldMappingController.saveMappingConfig('', '{"test":"data"}');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }

        System.assertEquals(true, exceptionThrown, 'Exception should be thrown');
    }

    // ================= TEST SAVE MAPPING CONFIG - NO JSON =================
    @isTest
    static void testSaveMappingConfig_NoJSON() {

        Boolean exceptionThrown = false;

        try {
            FieldMappingController.saveMappingConfig('Account', '');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }

        System.assertEquals(true, exceptionThrown, 'Exception should be thrown');

    }
    
}