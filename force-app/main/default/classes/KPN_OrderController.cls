public with sharing class KPN_OrderController {
    /**
* Get all order items for an order
*/
    @AuraEnabled(cacheable=true)
    public static List<OrderItemWrapper> getOrderItems(Id orderId) {
        if (orderId == null) {
            throw new AuraHandledException('Order Id is required.');
        }
        
        KPN_OrderItemWrapper.OrderResponse externalOrder = KPN_OrderServiceController.getOrderById(String.valueOf('ord_2025_123456'));
        System.debug('orderItems:'+externalOrder);
        try {
            List<OrderItemWrapper> items = new List<OrderItemWrapper>();
            if (externalOrder != null && externalOrder.orderItems != null) {
                for (KPN_OrderItemWrapper.OrderItemDetail detail : externalOrder.orderItems) {
                    OrderItemWrapper item = new OrderItemWrapper();
                    item.orderItemId = null; // Not yet inserted in Salesforce
                    item.productName = detail.productName;
                    item.unitPrice = detail.unitPrice;
                    item.quantity = detail.quantity;
                    item.totalPrice = detail.totalPrice;
                    items.add(item);
                }
            }
            for (OrderItem oi : [SELECT Id, Product2Id, Product2.Name, UnitPrice, Quantity, TotalPrice FROM OrderItem WHERE OrderId = :orderId ORDER BY Product2.Name ASC]) {
                OrderItemWrapper item = new OrderItemWrapper();
                item.orderItemId = oi.Id;
                item.productName = oi.Product2.Name;
                item.unitPrice = oi.UnitPrice;
                item.quantity = oi.Quantity;
                item.totalPrice = oi.TotalPrice;
                items.add(item);
            }
            return items;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching order items: ' + e.getMessage());
        }
    }
    
    /**
* Check if order is activated
*/
    @AuraEnabled(cacheable=true)
    public static Boolean isOrderActivated(Id orderId) {
        try {
            Order ord = [SELECT Status FROM Order WHERE Id = :orderId LIMIT 1];
            return ord.Status == 'Activated';
        } catch (Exception e) {
            throw new AuraHandledException('Error checking order status: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String activateOrderAPI(Id orderId) {
        try {
            Order ord = new Order(Id = orderId, Status = 'Activated');
            update ord;
            return 'Order activated successfully';
        } catch (Exception e) {
            throw new AuraHandledException('Error activating order: ' + e.getMessage());
        }
    }
    
    /**
* Activate an order
*/
    @AuraEnabled
    public static String activateOrder(Id orderId, List<OrderItemWrapper> selectedProducts) {
        String pricebookId; 
        String pricebookEntryId;
        System.debug('selectedProducts:' + selectedProducts);
        
        if (orderId == null) {
            throw new AuraHandledException('Order Id is required.');
        }
        if (selectedProducts == null || selectedProducts.isEmpty()) {
            throw new AuraHandledException('Please select at least one product to activate the order.');
        }
        
        try {
            Order ord = [SELECT Id, Pricebook2Id, Pricebook2.IsStandard, Status FROM Order WHERE Id = :orderId LIMIT 1];
            
            if (ord.Status == 'Activated') {
                return 'Order is already activated.';
            }
            
            if (ord.Pricebook2Id == null) {
                ord.Pricebook2Id = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
                update ord;
            }
            pricebookId = ord.Pricebook2Id;
            
            if (pricebookId == null) {
                throw new AuraHandledException('Pricebook is not set on the order.');
            }
            
            String standardPricebookId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
            Boolean isStandardPricebook = (pricebookId == standardPricebookId);
            List<Product2> productsToInsert = new List<Product2>();
            Map<String, OrderItemWrapper> externalProductsMap = new Map<String, OrderItemWrapper>();
            
            System.debug('Processing products...');
            for (OrderItemWrapper product : selectedProducts) {
                if (product == null) continue;
                
                // Check if product already exists in Salesforce (productId starts with '01t')
                if (product.productId != null && product.productId.startsWith('01t')) {
                    // Product exists in Salesforce - will handle via PricebookEntry
                    System.debug('Existing product: ' + product.productId);
                } else {
                    
                    Product2 newProduct = new Product2(
                        Name = product.productName,
                        ProductCode = product.productId,
                        Family = product.category,
                        IsActive = true
                    );
                    productsToInsert.add(newProduct);
                    externalProductsMap.put(product.productName, product);
                }
            }
            
            System.debug('Products to insert: ' + productsToInsert);
            if (!productsToInsert.isEmpty()) {
                insert productsToInsert;
            }
            
            List<PricebookEntry> standardPBEsToInsert = new List<PricebookEntry>();
            List<PricebookEntry> customPBEsToInsert = new List<PricebookEntry>();
            
            for (Product2 product : productsToInsert) {
                OrderItemWrapper apiProduct = externalProductsMap.get(product.Name);
                Decimal unitPrice = (apiProduct != null && apiProduct.unitPrice != null) ? apiProduct.unitPrice : 0;
                
                PricebookEntry standardPBE = new PricebookEntry(
                    Pricebook2Id = standardPricebookId,
                    Product2Id = product.Id,
                    UnitPrice = unitPrice,
                    IsActive = true
                );
                standardPBEsToInsert.add(standardPBE);
            }
            
            if (!standardPBEsToInsert.isEmpty()) {
                insert standardPBEsToInsert;
            }
            
            if (!isStandardPricebook) {
                for (Product2 product : productsToInsert) {
                    OrderItemWrapper apiProduct = externalProductsMap.get(product.Name);
                    Decimal unitPrice = (apiProduct != null && apiProduct.unitPrice != null) ? apiProduct.unitPrice : 0;
                    
                    PricebookEntry customPBE = new PricebookEntry(
                        Pricebook2Id = pricebookId,
                        Product2Id = product.Id,
                        UnitPrice = unitPrice,
                        IsActive = true
                    );
                    customPBEsToInsert.add(customPBE);
                }
                
                if (!customPBEsToInsert.isEmpty()) {
                    insert customPBEsToInsert;
                }
            }
            
            Set<String> allProductIds = new Set<String>();
            for (OrderItemWrapper prod : selectedProducts) {
                if (prod != null && prod.productId != null && prod.productId.startsWith('01t')) {
                    allProductIds.add(prod.productId);
                }
            }
            for (Product2 prod : productsToInsert) {
                allProductIds.add(prod.Id);
            }
            
            List<PricebookEntry> pricebookEntries = [
                SELECT Id, Product2Id, Product2.Name, Product2.ProductCode, UnitPrice 
                FROM PricebookEntry 
                WHERE Pricebook2Id = :pricebookId 
                AND Product2Id IN :allProductIds
                AND IsActive = true
            ];
            
            System.debug('PricebookEntries from Order pricebook: ' + pricebookEntries);
            
            Map<String, PricebookEntry> productIdToPBEMap = new Map<String, PricebookEntry>();
            Map<String, PricebookEntry> productNameToPBEMap = new Map<String, PricebookEntry>();
            Map<String, PricebookEntry> productCodeToPBEMap = new Map<String, PricebookEntry>();
            
            for (PricebookEntry pbe : pricebookEntries) {
                productIdToPBEMap.put(pbe.Product2Id, pbe);
                if (pbe.Product2.Name != null) {
                    productNameToPBEMap.put(pbe.Product2.Name, pbe);
                }
                if (pbe.Product2.ProductCode != null) {
                    productCodeToPBEMap.put(pbe.Product2.ProductCode, pbe);
                }
            }
            
            if (!isStandardPricebook) {
                List<PricebookEntry> missingCustomPBEs = new List<PricebookEntry>();
                
                for (OrderItemWrapper prod : selectedProducts) {
                    if (prod == null || prod.productId == null || !prod.productId.startsWith('01t')) continue;
                    
                    if (!productIdToPBEMap.containsKey(prod.productId)) {
                        List<Product2> existingProducts = [SELECT Id FROM Product2 WHERE Id = :prod.productId LIMIT 1];
                        if (!existingProducts.isEmpty()) {
                            Decimal unitPrice = (prod.unitPrice != null) ? prod.unitPrice : 0;
                            
                            PricebookEntry newPBE = new PricebookEntry(
                                Pricebook2Id = pricebookId,
                                Product2Id = prod.productId,
                                UnitPrice = unitPrice,
                                IsActive = true
                            );
                            missingCustomPBEs.add(newPBE);
                        }
                    }
                }
                
                if (!missingCustomPBEs.isEmpty()) {
                    insert missingCustomPBEs;
                    pricebookEntries.addAll(missingCustomPBEs);
                    for (PricebookEntry pbe : missingCustomPBEs) {
                        productIdToPBEMap.put(pbe.Product2Id, pbe);
                    }
                }
            }
            
            // Create OrderItems
            List<OrderItem> orderItemsToInsert = new List<OrderItem>();
            
            for (OrderItemWrapper apiProduct : selectedProducts) {
                if (apiProduct == null) continue;
                
                PricebookEntry matchingPBE = null;
                
                if (apiProduct.productId != null && apiProduct.productId.startsWith('01t')) {
                    matchingPBE = productIdToPBEMap.get(apiProduct.productId);
                }
                
                if (matchingPBE == null && apiProduct.productId != null) {
                    matchingPBE = productCodeToPBEMap.get(apiProduct.productId);
                }
                
                if (matchingPBE == null && apiProduct.productName != null) {
                    matchingPBE = productNameToPBEMap.get(apiProduct.productName);
                }
                
                if (matchingPBE == null) {
                    System.debug('WARNING: No PricebookEntry found for product: ' + apiProduct);
                    continue;
                }
                
                Decimal quantity = (apiProduct.quantity != null && apiProduct.quantity > 0) ? apiProduct.quantity : 1;
                Decimal unitPrice = (apiProduct.unitPrice != null && apiProduct.unitPrice > 0) ? apiProduct.unitPrice : matchingPBE.UnitPrice;
                
                OrderItem oi = new OrderItem(
                    OrderId = orderId,
                    PricebookEntryId = matchingPBE.Id,
                    Product2Id = matchingPBE.Product2Id,
                    Quantity = quantity,
                    UnitPrice = unitPrice
                );
                orderItemsToInsert.add(oi);
            }
            
            System.debug('OrderItems to insert: ' + orderItemsToInsert);
            
            if (!orderItemsToInsert.isEmpty()) {
                insert orderItemsToInsert;
            } else {
                throw new AuraHandledException('No valid products found to add to the order.');
            }
            
            // Activate the Order
            ord.Status = 'Activated';
            update ord;
            
            return 'Order activated successfully with ' + orderItemsToInsert.size() + ' product(s).';
            
        } catch (Exception e) {
            System.debug('ERROR: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error activating order: ' + e.getMessage());
        }
    }
    
    
    // ---------- Wrapper Classes ----------
    public class OrderItemWrapper {
        @AuraEnabled public String orderItemId { get; set; }
        @AuraEnabled public String productId { get; set; }
        @AuraEnabled public String productName { get; set; }
        @AuraEnabled public Decimal unitPrice { get; set; }
        @AuraEnabled public Decimal listPrice { get; set; }
        @AuraEnabled public Decimal quantity { get; set; }
        @AuraEnabled public Decimal totalPrice { get; set; }
        @AuraEnabled public String category { get; set; }
        public OrderItemWrapper() {}
        
        public OrderItemWrapper(Map<String, Object> data) {
            orderItemId = (String) data.get('orderItemId');
            productId = (String) data.get('productId');
            productName = (String) data.get('productName');
            unitPrice = (data.containsKey('unitPrice')) ? Decimal.valueOf(String.valueOf(data.get('unitPrice'))) : 0;
            listPrice = (data.containsKey('listPrice')) ? Decimal.valueOf(String.valueOf(data.get('listPrice'))) : 0;
            quantity = (data.containsKey('quantity')) ? Decimal.valueOf(String.valueOf(data.get('quantity'))) : 0;
            totalPrice = (data.containsKey('totalPrice')) ? Decimal.valueOf(String.valueOf(data.get('totalPrice'))) : 0;
            category = (String) data.get('category');
        }
    }
}