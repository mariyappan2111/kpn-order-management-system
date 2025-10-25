public with sharing class KPN_OrderServiceController extends KPN_IntegrationsBase{
    private static final String NAMED_CREDENTIAL = 'callout:Open_ExternalAPI';

    public static Map<String, Object> createOrder(KPN_OrderItemWrapper.CreateOrderRequest orderRequest) {
        String endpoint = NAMED_CREDENTIAL + '/Orders/1.0.0/orders';
        String body = JSON.serialize(orderRequest);
        HttpResponse res = sendRequest('POST', endpoint, body);

        if (res.getStatusCode() != 201 && res.getStatusCode() != 200) {
            throw new CalloutException('Failed to create order: ' + res.getBody());
        }
        return (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    }

    public static Map<String, Object> getAllOrders() {
        String endpoint = NAMED_CREDENTIAL + '/Orders/1.0.0/orders';
        HttpResponse res = sendRequest('GET', endpoint, null);

        if (res.getStatusCode() != 200) {
            throw new CalloutException('Failed to fetch orders: ' + res.getBody());
        }
        return (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    }

    public static KPN_OrderItemWrapper.OrderResponse getOrderById(String orderId) {
        String endpoint = NAMED_CREDENTIAL + '/Orders/1.0.0/orders/' + EncodingUtil.urlEncode(orderId, 'UTF-8');
        HttpResponse res = sendRequest('GET', endpoint, null);

        if (res.getStatusCode() != 200) {
            throw new CalloutException('Failed to fetch order: ' + res.getBody());
        }

        System.debug('res body:' + res.getBody());
        return (KPN_OrderItemWrapper.OrderResponse) JSON.deserialize(res.getBody(), KPN_OrderItemWrapper.OrderResponse.class);
    }
}