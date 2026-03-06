public class generateHtmlFromJson {

    public static void processTemplate(Id recordId, String mappingJson) {

   
        Map<String,Object> jsonMap =
        (Map<String,Object>) JSON.deserializeUntyped(mappingJson);

        String objectName = (String) jsonMap.get('objectName');

        List<Object> fields =
        (List<Object>) jsonMap.get('fields');

        List<String> fieldList = new List<String>();

        for(Object obj : fields){

            Map<String,Object> field =
            (Map<String,Object>) obj;

            fieldList.add((String) field.get('apiName'));
        }

        // Build Dynamic SOQL
        String soql = 'SELECT ' + String.join(fieldList, ',') +
                      ' FROM ' + objectName +
                      ' WHERE Id = :recordId';

        // Query record dynamically
        SObject record = Database.query(soql);

        Map<String,Object> data =
        record.getPopulatedFieldsAsMap();

        // HTML Template (you can move this to metadata later)
        
       String html = '<h2>Record Details</h2>';

for(String field : fieldList){
    
    html += '<p>'+field+': {{'+objectName+'.'+field+'}}</p>';
}
        // Replace placeholders
      for(String key : data.keySet()){

    html = html.replace(
        '{{'+objectName+'.'+key+'}}',
        String.valueOf(data.get(key))
    );
}

        // Create new junction record
        Template_mapping_output__c outputRec =
        new Template_mapping_output__c();

        outputRec.Output_Html__c = html;

        insert outputRec;
    }
}