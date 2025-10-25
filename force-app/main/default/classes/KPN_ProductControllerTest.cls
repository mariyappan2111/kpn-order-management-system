@IsTest
public with sharing class KPN_ProductControllerTest {
    @TestSetup
    static void setupData() {
        Id stdPbId = Test.getStandardPricebookId();
        
        Product2 prod = new Product2(Name = 'Fiber 1 Gbps', ProductCode = 'PROD001', IsActive = true);
        insert prod;
        
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod.Id,
            UnitPrice = 50,
            IsActive = true
        );
        insert pbe;
        
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        Order ord = new Order(
            AccountId = acc.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = stdPbId
        );
        insert ord;
        
        OrderItem oi = new OrderItem(
            OrderId = ord.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2,
            UnitPrice = 50
        );
        insert oi;
    }
    
    @IsTest
    static void testGetAvailableProductFromAPI() {
        List<Map<String, Object>> apiProducts = new List<Map<String, Object>>{
            new Map<String, Object>{
                'id' => 'PROD001', 'name' => 'Fiber 1 Gbps',
                    'category' => 'Internet', 'description' => 'High speed fiber',
                    'price' => 50, 'currencytype' => 'EUR', 'isBundle' => false
                    },
                        new Map<String, Object>{
                            'id' => 'PROD_NEW', 'name' => 'Modem Router',
                                'category' => 'Hardware', 'description' => 'WiFi 6 router',
                                'price' => 120, 'currencytype' => 'EUR', 'isBundle' => false
                                }
        };
            
            String mockResponse = JSON.serialize(apiProducts);
        Test.setMock(HttpCalloutMock.class, new KPN_MockHttpResponse(200, mockResponse));
        Order ord = [SELECT Id FROM Order LIMIT 1];
        Test.startTest();
        List<KPN_ProductWrapper> products = KPN_ProductController.getAvailableProducts(ord.Id);
        KPN_ProductController.getCurrentUser();
        Test.stopTest();
    }
    
    @IsTest
    static void testGetAvailableProducts_ApiOnly_NoSalesforceProducts() {
        List<KPN_ProductWrapper> apiProductList = new List<KPN_ProductWrapper>();
        KPN_ProductWrapper mock = new KPN_ProductWrapper();
        mock.id = 'PROD001';
        mock.name = 'Fiber 1 Gbps';
        apiProductList.add(mock);
        Order ord = [SELECT Id FROM Order LIMIT 1];
        List<Map<String, Object>> apiProducts = new List<Map<String, Object>>{
            new Map<String, Object>{
                'id' => 'PROD999', 'name' => '5G SIM Plan',
                    'category' => 'Mobile', 'description' => 'Unlimited 5G',
                    'price' => 30, 'currencytype' => 'EUR', 'isBundle' => false
                    }
        };
            
            String mockResponse = JSON.serialize(apiProducts);
        Test.setMock(HttpCalloutMock.class, new KPN_MockHttpResponse(200, mockResponse));
        
        Test.startTest();
        List<KPN_ProductWrapper> products = KPN_ProductController.getAvailableProducts(null);
        Test.stopTest();
    }
    
    @IsTest
    static void testGetAvailableProductsException() { 
        
        List<KPN_ProductWrapper> apiProductList = new List<KPN_ProductWrapper>();
        KPN_ProductWrapper wrapper = new KPN_ProductWrapper();
        wrapper.id = null;
        wrapper.name = null;
        apiProductList.add(wrapper);
        List<Map<String, Object>> apiProducts = new List<Map<String, Object>>{
            new Map<String, Object>{
                'id' => null, 'name' => null,
                    'category' => 'Mobile', 'description' => 'Unlimited 5G',
                    'price' => 30, 'currencytype' => 'EUR', 'isBundle' => false
                    }
        };
            
            String mockResponse = JSON.serialize(apiProducts);
        
        Test.setMock(HttpCalloutMock.class, new KPN_MockHttpResponse(500, 'Error'));
        Order ord = [SELECT Id FROM Order LIMIT 1];
        Boolean caught = false;
        try {
            Test.startTest();
            KPN_ProductController.getAvailableProducts(null);
            Test.stopTest();
        } catch (Exception e) {
            System.debug(e.getMessage());
        }
    }
    
    @IsTest
    static void testGetAvailableProducts_NoPricebook_AndApiError() {
        Account acc = new Account(Name = 'Test Account 2');
        insert acc;
        Order ord = new Order(
            AccountId = acc.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft'
        );
        Insert ord;
        
        Test.setMock(HttpCalloutMock.class, new KPN_MockHttpResponse(404, 'Server Error'));
        
        Boolean pricebookException = false;
        Boolean apiServiceException = false;
        try {
            
            KPN_ProductController.getAvailableProducts(ord.Id);
            Test.stopTest();
        } catch (AuraHandledException e) {
            pricebookException = e.getMessage().contains('Order must have a Pricebook assigned.');
        }
        try {
            Test.startTest();
            KPN_ProductController.getAvailableProducts(null);
            Test.stopTest();
        } catch (AuraHandledException e) {
           apiServiceException = e.getMessage().contains('Error fetching products');
        }       
    }
}