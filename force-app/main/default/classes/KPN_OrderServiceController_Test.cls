@IsTest
public with sharing class KPN_OrderServiceController_Test {
    @IsTest
    public static void testGetOrderById() {
        String mockBody = JSON.serialize(new Map<String, Object>{
            'orderId' => 'ORD_2025_123456',
            'orderNumber' => 'ORD-001',
            'status' => 'Created',
            'orderItems' => new List<Object>{
                new Map<String, Object>{
                    'productId' => 'PROD-001',
                    'productName' => 'Fiber 1 Gbps Home Bundle',
                    'unitPrice' => 49.99,
                    'quantity' => 1,
                    'totalPrice' => 49.99
                }
            }
        });

        Test.setMock(HttpCalloutMock.class, new KPN_MockHttpResponse(200, mockBody));
        KPN_OrderItemWrapper.OrderResponse response = KPN_OrderServiceController.getOrderById('ORD_2025_123456');
        System.assertEquals('ORD_2025_123456', response.orderId);
        System.assertEquals('Fiber 1 Gbps Home Bundle', response.orderItems[0].productName);
    }

    @IsTest
    public static void testGetAllOrders() {
        Test.setMock(HttpCalloutMock.class, new KPN_MockHttpResponse(200, '{"orders":[]}'));
        Map<String, Object> res = KPN_OrderServiceController.getAllOrders();
        System.assertNotEquals(null, res);
    }

    @IsTest
    public static void testCreateOrder() {
        Test.setMock(HttpCalloutMock.class, new KPN_MockHttpResponse(201, '{"orderId":"ORD_2025_123456"}'));
        KPN_OrderItemWrapper.CreateOrderRequest req = new KPN_OrderItemWrapper.CreateOrderRequest();
        req.customer = new KPN_OrderItemWrapper.Customer();
        req.customer.customerId = 'CUST1';
       
        KPN_OrderItemWrapper.OrderItem orderItem = new KPN_OrderItemWrapper.OrderItem();
        orderItem.productId = 'PROD-001';
        orderItem.quantity = 1;
        
        req.orderItems = new List<KPN_OrderItemWrapper.OrderItem>();
        req.orderItems.add(orderItem);

        Map<String, Object> res = KPN_OrderServiceController.createOrder(req);
        System.assertEquals('ORD_2025_123456', res.get('orderId'));
    }
}