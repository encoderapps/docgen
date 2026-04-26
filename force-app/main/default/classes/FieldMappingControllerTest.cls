@isTest
public class FieldMappingControllerTest {

    // ================= TEST GET ALL OBJECTS =================
    @isTest
    static void testGetAllObjects() {

        Test.startTest();
        List<FieldMappingController.ObjectWrapper> objects =
            FieldMappingController.getAllObjects();
        Test.stopTest();

        System.assertNotEquals(null, objects, 'Object list should not be null');
        System.assert(objects.size() > 0, 'Object list should not be empty');

        FieldMappingController.ObjectWrapper obj = objects[0];
        System.assertNotEquals(null, obj.label, 'Object label should not be null');
        System.assertNotEquals(null, obj.apiName, 'Object API name should not be null');
    }

    // ================= TEST GET OBJECT FIELDS =================
    @isTest
    static void testGetObjectFields() {

        Test.startTest();
        List<FieldMappingController.FieldWrapper> fields =
            FieldMappingController.getObjectFields('Account');
        Test.stopTest();

        System.assertNotEquals(null, fields, 'Fields should not be null');
        System.assert(fields.size() > 0, 'Fields should not be empty');

        FieldMappingController.FieldWrapper f = fields[0];
        System.assertNotEquals(null, f.label, 'Field label should not be null');
        System.assertNotEquals(null, f.apiName, 'Field API name should not be null');
        System.assertNotEquals(null, f.type, 'Field type should not be null');
    }

    // ================= TEST GET OBJECT FIELDS - INVALID =================
    @isTest
    static void testGetObjectFieldsInvalid() {

        Test.startTest();
        List<FieldMappingController.FieldWrapper> fields =
            FieldMappingController.getObjectFields('');
        Test.stopTest();

        System.assertEquals(0, fields.size(), 'Fields should be empty for invalid object');
    }

    // ================= TEST GET RELATED OBJECTS =================
    @isTest
    static void testGetRelatedObjects() {

        Test.startTest();
        List<FieldMappingController.RelatedObjectWrapper> related =
            FieldMappingController.getRelatedObjects('Account');
        Test.stopTest();

        System.assertNotEquals(null, related, 'Related objects should not be null');

        if (!related.isEmpty()) {
            FieldMappingController.RelatedObjectWrapper obj = related[0];
            System.assertNotEquals(null, obj.label, 'Related object label should not be null');
            System.assertNotEquals(null, obj.apiName, 'Related object API name should not be null');
        }
    }

    // ================= TEST GET RELATED OBJECTS - INVALID =================
    @isTest
    static void testGetRelatedObjectsInvalid() {

        Test.startTest();
        List<FieldMappingController.RelatedObjectWrapper> related =
            FieldMappingController.getRelatedObjects('');
        Test.stopTest();

        System.assertEquals(0, related.size(), 'Related objects should be empty for invalid input');
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

        System.assertNotEquals(null, recordId, 'Record Id should not be null');

        Mapping_Config__c rec = [
            SELECT Id, Source_Object__c, JSON_Structure__c
            FROM Mapping_Config__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        System.assertEquals('Account', rec.Source_Object__c, 'Source object mismatch');
        System.assertEquals(jsonData, rec.JSON_Structure__c, 'JSON data mismatch');
    }

    // ================= TEST SAVE MAPPING CONFIG - NO OBJECT =================
    @isTest
    static void testSaveMappingConfigNoObject() {

        Boolean exceptionThrown = false;

        try {
            FieldMappingController.saveMappingConfig('', '{"test":"data"}');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }

        System.assertEquals(true, exceptionThrown, 'Exception should be thrown when object is blank');
    }

    // ================= TEST SAVE MAPPING CONFIG - NO JSON =================
    @isTest
    static void testSaveMappingConfigNoJson() {

        Boolean exceptionThrown = false;

        try {
            FieldMappingController.saveMappingConfig('Account', '');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }

        System.assertEquals(true, exceptionThrown, 'Exception should be thrown when JSON is blank');

    }
}