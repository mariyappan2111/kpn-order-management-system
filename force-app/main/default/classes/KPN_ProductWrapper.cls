public with sharing class KPN_ProductWrapper {
    public KPN_ProductWrapper() { }
    @AuraEnabled public String productName;
    @AuraEnabled public String productId;
    @AuraEnabled public String pricebookEntryId;
    @AuraEnabled public Decimal listPrice;
    @AuraEnabled public Boolean isInOrder;
    @AuraEnabled public Decimal quantityOnOrder;
    @AuraEnabled public String id;
    @AuraEnabled public String name;
    @AuraEnabled public String category;
    @AuraEnabled public String description;
    @AuraEnabled public Decimal price;
    @AuraEnabled public String currencyType;
    @AuraEnabled public Boolean isBundle;

    public KPN_ProductWrapper(Map<String, Object> data) {
        productId = (String) data.get('id');
        id = (String) data.get('id');
        productName = (String) data.get('name');
        category = (String) data.get('category');
        description = (String) data.get('description');
        listPrice = (data.containsKey('price')) ? Decimal.valueOf(String.valueOf(data.get('price'))) : 0;
        currencyType = (String) data.get('currencytype');
        isBundle = (Boolean) data.get('isBundle');
    }
}