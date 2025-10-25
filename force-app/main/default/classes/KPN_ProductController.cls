public With sharing class KPN_ProductController {
    public static Id priceBookId;
    public static Id expricebookEntryId;

    @AuraEnabled(cacheable=true)
    public static List<KPN_ProductWrapper> getAvailableProducts() {
        List<KPN_ProductWrapper> apiProducts = KPN_ProductsServiceController.getAvailableProducts();
        String orderId;
        Map<Id, AggregateResult> productOrderQuantities = new Map<Id, AggregateResult>();
        Map<Id, OrderItem> existingOrderItems = new Map<Id, OrderItem>();
        Order order = new Order();
        
        try {
            if(orderId != null) {
                order = [SELECT Id, Pricebook2Id, Status FROM Order WHERE Id = :orderId LIMIT 1];
                priceBookId = order.Pricebook2Id;
                
                for (OrderItem oi : [
                    SELECT Id, Product2Id, Quantity 
                    FROM OrderItem 
                    WHERE OrderId = :orderId
                ]) {
                    existingOrderItems.put(oi.Product2Id, oi);
                }
            } else {
                priceBookId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
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

            // Merge API products with Salesforce products
            for (KPN_ProductWrapper apiProduct : apiProducts) {
                if (productsByIdMap.containsKey(apiProduct.id)) {  // If exists in Salesforce, merge
                    KPN_ProductWrapper sfProd = productsByIdMap.get(apiProduct.id);
                    sfProd.category = apiProduct.category;
                    sfProd.description = apiProduct.description;
                    sfProd.currencyType = apiProduct.currencyType;
                    sfProd.isBundle = apiProduct.isBundle;
                    products.add(sfProd);
                    productsByIdMap.remove(apiProduct.id);
                } else {
                    products.add(apiProduct); // Product only from API
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
    
    /**
* Add or increment product quantity on order
*/
    @AuraEnabled
    public static String addProductToOrder(Id orderId, Id pricebookEntryId, Id productId) {
        
        if( pricebookEntryId == null ) {
            pricebookEntryId = expricebookEntryId;
        }

        if( orderId == null ) {
            //orderId = KPN_OrderController.createOrder();
            throw new AuraHandledException('Order ID is required to add a product.');
        }
        if( productId == null ) {
            throw new AuraHandledException('Product ID is required to add a product.');
        }
        Order ord = [SELECT Status FROM Order WHERE Id = :orderId LIMIT 1];
        if (ord.Status == 'Activated') {
            throw new AuraHandledException('Cannot modify an activated order.');
        }

        try {
            // Check if product already exists on order
            List<OrderItem> existingItems = [
                SELECT Id, Quantity 
                FROM OrderItem 
                WHERE OrderId = :orderId 
                AND Product2Id = :productId
                LIMIT 1
            ];
            
            if (!existingItems.isEmpty()) {
                // Increment quantity
                OrderItem oi = existingItems[0];
                oi.Quantity += 1;
                update oi;
                return 'updated';
            } else {
                // Create new OrderItem
                PricebookEntry pbe = [
                    SELECT UnitPrice 
                    FROM PricebookEntry 
                    WHERE Id = :PricebookEntryId 
                    LIMIT 1
                ];
                
                OrderItem newOi = new OrderItem(
                    OrderId = orderId,
                    PricebookEntryId = pricebookEntryId,
                    Product2Id = productId,
                    Quantity = 1,
                    UnitPrice = pbe.UnitPrice
                );
                insert newOi;
                return 'created';
            }
            
        } catch (Exception e) {
            throw new AuraHandledException('Error adding product: ' + e.getMessage());
        }
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