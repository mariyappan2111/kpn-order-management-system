public With sharing class KPN_ProductController {
    public static Id priceBookId;
    public static Id expricebookEntryId;
    
    @AuraEnabled(cacheable=true)
    public static List<KPN_ProductWrapper> getAvailableProducts(String orderId) {
       try {
        List<KPN_ProductWrapper> apiProducts = KPN_ProductsServiceController.getAvailableProducts();
        // String orderId;
        Map<Id, AggregateResult> productOrderQuantities = new Map<Id, AggregateResult>();
        Map<Id, OrderItem> existingOrderItems = new Map<Id, OrderItem>();
        Order order = new Order();
        
        
            if(orderId != null) {
                order = [SELECT Id, Pricebook2Id, Status FROM Order WHERE Id = :orderId LIMIT 1];
                priceBookId = order.Pricebook2Id;
                for (OrderItem oi : [SELECT Id, Product2Id, Quantity FROM OrderItem  WHERE OrderId = :orderId]) {
                    existingOrderItems.put(oi.Product2Id, oi);
                }
            } else {
                if(Test.isRunningTest()) {
                    priceBookId = Test.getStandardPricebookId();
                } else {
                    priceBookId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
                }
                System.debug('Standard Pricebook Id: ' + priceBookId);
            }
            
            if (priceBookId == null) {
                throw new AuraHandledException('Order must have a Pricebook assigned.');
            }
            
            List<PricebookEntry> pricebookEntries = [
                SELECT Id, Product2Id, Product2.Name, UnitPrice, IsActive
                FROM PricebookEntry
                WHERE Pricebook2Id = :priceBookId
                AND IsActive = true
                ORDER BY Product2.Name ASC
            ];
            
            System.debug('Pricebook Entries: ' + pricebookEntries);
            Map<String, KPN_ProductWrapper> productsByIdMap = new Map<String, KPN_ProductWrapper>();
            List<KPN_ProductWrapper> products = new List<KPN_ProductWrapper>();
            for (PricebookEntry pbe : pricebookEntries) {
                KPN_ProductWrapper pw = new KPN_ProductWrapper();
                pw.productId = pbe.Product2Id;
                pw.pricebookEntryId = pbe.Id;
                pw.productName = pbe.Product2.Name;
                pw.listPrice = pbe.UnitPrice;
                pw.isInOrder = existingOrderItems.containsKey(pbe.Product2Id);
                pw.quantityOnOrder = pw.isInOrder ? existingOrderItems.get(pbe.Product2Id).Quantity : 0;
                productsByIdMap.put(pw.productId, pw);
            }
            System.debug(apiProducts);
            System.debug(productsByIdMap);
            
            for (KPN_ProductWrapper apiProduct : apiProducts) {
                System.debug(productsByIdMap.containsKey(apiProduct.id));
                System.debug(apiProduct.id);
                if (productsByIdMap.containsKey(apiProduct.id)) {
                    KPN_ProductWrapper sfProd = productsByIdMap.get(apiProduct.id);
                    sfProd.category = apiProduct.category;
                    sfProd.description = apiProduct.description;
                    sfProd.currencyType = apiProduct.currencyType;
                    sfProd.isBundle = apiProduct.isBundle;
                    products.add(sfProd);
                    productsByIdMap.remove(apiProduct.id);
                } else {
                    products.add(apiProduct);
                }
            }
            // Add any Salesforce-only products that were not in API
            products.addAll(productsByIdMap.values());
            System.debug('Products fetched: ' + products);
            return products;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching products: ' + e.getMessage());
        }
    }
    
    public static User getCurrentUser(){
        User userObj = [select Id, FirstName, LastName From user where id=:userinfo.getuserid()];
        return userObj;
    }
    
    // Wrapper class
    public class ProductWrapper {
        @AuraEnabled public Id productId;
        @AuraEnabled public Id pricebookEntryId; 
        @AuraEnabled public String productName;
        @AuraEnabled public Decimal listPrice;
        @AuraEnabled public Boolean isInOrder;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal totalPrice;
        @AuraEnabled public Id orderItemId;
    }
}