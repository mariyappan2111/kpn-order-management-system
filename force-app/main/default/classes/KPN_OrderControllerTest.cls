@IsTest(SeeAllData=false)
public with sharing class KPN_OrderControllerTest {
    
    @TestSetup
    static void setupData() {
        Id standardPb = Test.getStandardPricebookId();
        Pricebook2 customPb = new Pricebook2(Name='Test CustomPricebook', IsActive=true);
        insert customPb;

        Product2 prod1 = new Product2(
            Name = 'Fiber 1 Gbps Home Bundle',
            ProductCode = 'PLAN001',
            IsActive = true,
            Family = 'Broadband'
        );
        insert prod1;

        Product2 prod2 = new Product2(
            Name = 'Mobile Unlimited Plan',
            ProductCode = 'PLAN002',
            IsActive = true,
            Family = 'Mobile'
        );
        insert prod2;

        List<PricebookEntry> standardPBEs = new List<PricebookEntry>();
        standardPBEs.add(new PricebookEntry(
            Pricebook2Id = standardPb,
            Product2Id = prod1.Id,
            UnitPrice = 49.99,
            IsActive = true
        ));
        standardPBEs.add(new PricebookEntry(
            Pricebook2Id = standardPb,
            Product2Id = prod2.Id,
            UnitPrice = 39.99,
            IsActive = true
        ));
        insert standardPBEs;

        List<PricebookEntry> customPBEs = new List<PricebookEntry>();
        customPBEs.add(new PricebookEntry(
            Pricebook2Id = customPb.Id,
            Product2Id = prod1.Id,
            UnitPrice = 49.99,
            IsActive = true
        ));
        customPBEs.add(new PricebookEntry(
            Pricebook2Id = customPb.Id,
            Product2Id = prod2.Id,
            UnitPrice = 39.99,
            IsActive = true
        ));
        insert customPBEs;

        Account acc = new Account(Name='KPN NL Test Account');
        insert acc;

        Order ord = new Order(
            AccountId = acc.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = customPb.Id
        );
        insert ord;
    }

    @IsTest
    static void testActivateOrder_WithSalesforceProduct() {
        Order ord = [SELECT Id, Pricebook2Id FROM Order LIMIT 1];
        Product2 prod = [SELECT Id, Name FROM Product2 WHERE ProductCode = 'PLAN001' LIMIT 1];
        
        KPN_OrderController.OrderItemWrapper wrap = new KPN_OrderController.OrderItemWrapper();
        wrap.productId = prod.Id;
        wrap.productName = prod.Name;
        wrap.unitPrice = 49.99;
        wrap.quantity = 2;
        wrap.totalPrice = 99.98;
        wrap.category = 'Broadband';

        Test.startTest();
        String result = KPN_OrderController.activateOrder(ord.Id, new List<KPN_OrderController.OrderItemWrapper>{wrap});
        Test.stopTest();

        System.assert(result.contains('successfully'), 'Activation should be successful');
        Order updatedOrd = [SELECT Status FROM Order WHERE Id = :ord.Id];
        System.assertEquals('Activated', updatedOrd.Status, 'Order status should be Activated');
        
        List<OrderItem> orderItems = [SELECT Id, Quantity, UnitPrice FROM OrderItem WHERE OrderId = :ord.Id];
        System.assertEquals(1, orderItems.size(), 'Should have 1 order item');
        System.assertEquals(2, orderItems[0].Quantity, 'Quantity should be 2');
    }

    @IsTest
    static void testActivateOrder_WithAPIProduct() {
        Order ord = [SELECT Id, Pricebook2Id FROM Order LIMIT 1];
        
        KPN_OrderController.OrderItemWrapper apiWrap = new KPN_OrderController.OrderItemWrapper();
        apiWrap.productId = 'prod_fiber_1gbps_bundle'; // External ID
        apiWrap.productName = 'External Fiber Bundle';
        apiWrap.unitPrice = 79.99;
        apiWrap.quantity = 1;
        apiWrap.totalPrice = 79.99;
        apiWrap.category = 'Bundle';

        Test.startTest();
        String result = KPN_OrderController.activateOrder(ord.Id, new List<KPN_OrderController.OrderItemWrapper>{apiWrap});
        Test.stopTest();
        System.assert(result.contains('successfully'), 'Activation should be successful');
        
        List<Product2> newProducts = [SELECT Id, Name, ProductCode FROM Product2 WHERE Name = 'External Fiber Bundle'];
        System.assertEquals(1, newProducts.size(), 'New product should be created');
        System.assertEquals('prod_fiber_1gbps_bundle', newProducts[0].ProductCode, 'Product code should match');
    }

    @IsTest
    static void testActivateOrder_MixedProducts() {
        Order ord = [SELECT Id, Pricebook2Id FROM Order LIMIT 1];
        Product2 sfProduct = [SELECT Id, Name FROM Product2 WHERE ProductCode = 'PLAN001' LIMIT 1];
        
        List<KPN_OrderController.OrderItemWrapper> products = new List<KPN_OrderController.OrderItemWrapper>();
        
        KPN_OrderController.OrderItemWrapper sfWrap = new KPN_OrderController.OrderItemWrapper();
        sfWrap.productId = sfProduct.Id;
        sfWrap.productName = sfProduct.Name;
        sfWrap.unitPrice = 49.99;
        sfWrap.quantity = 1;
        sfWrap.totalPrice = 49.99;
        sfWrap.category = 'Broadband';
        products.add(sfWrap);
        
        KPN_OrderController.OrderItemWrapper apiWrap = new KPN_OrderController.OrderItemWrapper();
        apiWrap.productId = 'prod_mobile_unlimited';
        apiWrap.productName = 'API Mobile Plan';
        apiWrap.unitPrice = 29.99;
        apiWrap.quantity = 3;
        apiWrap.totalPrice = 89.97;
        apiWrap.category = 'Mobile';
        products.add(apiWrap);

        Test.startTest();
        String result = KPN_OrderController.activateOrder(ord.Id, products);
        Test.stopTest();

        System.assert(result.contains('successfully'), 'Activation should be successful');
        List<OrderItem> orderItems = [SELECT Id FROM OrderItem WHERE OrderId = :ord.Id];
        System.assertEquals(2, orderItems.size(), 'Should have 2 order items');
    }

    @IsTest
    static void testGetOrderItems_WithSalesforceProducts() {
        Order ord = [SELECT Id FROM Order LIMIT 1];
        PricebookEntry pbe = [SELECT Id, Product2Id FROM PricebookEntry WHERE Pricebook2.IsStandard = false LIMIT 1];
        
        OrderItem oi = new OrderItem(
            OrderId = ord.Id,
            PricebookEntryId = pbe.Id,
            Product2Id = pbe.Product2Id,
            Quantity = 2,
            UnitPrice = 49.99
        );
        insert oi;

        Test.setMock(HttpCalloutMock.class, new KPN_OrderServiceMock());

        Test.startTest();
        List<KPN_OrderController.OrderItemWrapper> items = KPN_OrderController.getOrderItems(ord.Id);
        Test.stopTest();

        System.assert(items.size() > 0, 'Should return order items');
        System.assertNotEquals(null, items[0].productName, 'Product name should not be null');
    }

    @IsTest
    static void testGetOrderItems_NullOrderId() {
        Test.startTest();
        try {
            KPN_OrderController.getOrderItems(null);
            System.assert(false, 'Should throw exception');
        } catch (AuraHandledException e) {
           System.debug(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testIsOrderActivated_Draft() {
        Order ord = [SELECT Id FROM Order WHERE Status = 'Draft' LIMIT 1];
        
        Test.startTest();
        Boolean result = KPN_OrderController.isOrderActivated(ord.Id);
        Test.stopTest();

        System.assertEquals(false, result, 'Draft order should not be activated');
    }

    @IsTest
    static void testIsOrderActivated_Activated() {
        Order ord = [SELECT Id FROM Order LIMIT 1];
        
         PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Pricebook2.Name = 'Test CustomPricebook' LIMIT 1];
        
        Insert new OrderItem(
            OrderId = ord.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 49.99
        );
        
        ord.Status = 'Activated';
        update ord;
        
        Test.startTest();
        Boolean result = KPN_OrderController.isOrderActivated(ord.Id);
        Test.stopTest();

        System.assertEquals(true, result, 'Order should be activated');
    }

    @IsTest
    static void testActivateOrderAPI() {
        Order ord = [SELECT Id, Status FROM Order LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Pricebook2.Name = 'Test CustomPricebook' LIMIT 1];
        
        Insert new OrderItem(
            OrderId = ord.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 49.99
        );

        Test.startTest();
        String result = KPN_OrderController.activateOrderAPI(ord.Id);
        Test.stopTest();

        System.assert(result.contains('successfully'), 'Should activate successfully');
        Order updatedOrd = [SELECT Status FROM Order WHERE Id = :ord.Id];
        System.assertEquals('Activated', updatedOrd.Status, 'Order status should be Activated');
    }

    @IsTest
    static void testActivateOrder_AlreadyActivated() {
        Order ord = [SELECT Id FROM Order LIMIT 1];

        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Pricebook2.Name = 'Test CustomPricebook' LIMIT 1];
        OrderItem oi = new OrderItem(
            OrderId = ord.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 49.99
        );
        insert oi;

        ord.Status = 'Activated';
        update ord;
        
        Product2 prod = [SELECT Id, Name FROM Product2 LIMIT 1];
        KPN_OrderController.OrderItemWrapper wrap = new KPN_OrderController.OrderItemWrapper();
        wrap.productId = prod.Id;
        wrap.productName = prod.Name;
        wrap.unitPrice = 49.99;
        wrap.quantity = 1;
        wrap.totalPrice = 49.99;

        Test.startTest();
        String result = KPN_OrderController.activateOrder(ord.Id, new List<KPN_OrderController.OrderItemWrapper>{wrap});
        Test.stopTest();

        System.assert(result.contains('already activated'), 'Should return already activated message');
    }

    @IsTest
    static void testActivateOrder_EmptyProducts() {
        Order ord = [SELECT Id FROM Order LIMIT 1];
        
        Test.startTest();
        try {
            KPN_OrderController.activateOrder(ord.Id, new List<KPN_OrderController.OrderItemWrapper>());
            System.assert(false, 'Should throw exception');
        } catch (Exception e) { 
            System.debug(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testOrderItemWrapper_Constructor() {
        Map<String, Object> data = new Map<String, Object>{
            'orderItemId' => 'OI123',
            'productId' => 'PROD001',
            'productName' => 'Test Product',
            'unitPrice' => 99.99,
            'listPrice' => 99.99,
            'quantity' => 2,
            'totalPrice' => 199.98,
            'category' => 'Mobile'
        };

        Test.startTest();
        KPN_OrderController.OrderItemWrapper wrapper = new KPN_OrderController.OrderItemWrapper(data);
        Test.stopTest();

        System.assertEquals('Test Product', wrapper.productName, 'Product name should match');
        System.assertEquals(99.99, wrapper.unitPrice, 'Unit price should match');
        System.assertEquals(2, wrapper.quantity, 'Quantity should match');
        System.assertEquals('Mobile', wrapper.category, 'Category should match');
    }

    private class KPN_OrderServiceMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            
            String mockResponse = JSON.serialize(new Map<String, Object>{
                'orderId' => 'ORD_2025_123456',
                'orderNumber' => 'ORD-2025-123456',
                'status' => 'confirmed',
                'orderItems' => new List<Object>{
                    new Map<String, Object>{
                        'productId' => 'PRD_001',
                        'productName' => 'API Fiber Bundle',
                        'unitPrice' => 79.99,
                        'quantity' => 1,
                        'totalPrice' => 79.99,
                        'category' => 'Bundle'
                    },
                    new Map<String, Object>{
                        'productId' => 'PRD_002',
                        'productName' => 'API Mobile Plan',
                        'unitPrice' => 29.99,
                        'quantity' => 2,
                        'totalPrice' => 59.98,
                        'category' => 'Mobile'
                    }
                }
            });
            
            res.setBody(mockResponse);
            return res;
        }
    }
}