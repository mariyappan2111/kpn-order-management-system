public with sharing class KPN_ProductsServiceController extends KPN_IntegrationsBase{
    private static final String NAMED_CREDENTIAL = 'callout:Open_ExternalAPI';
   // private static final String BASE_URL = 'https://virtserver.swaggerhub.com/go2clouds/product/1.0.0/products';
    public static List<KPN_ProductWrapper> getAvailableProducts() {
        String endpoint = NAMED_CREDENTIAL + '/product/1.0.0/products';
        HttpResponse res = sendRequest('GET', endpoint, null);

        if (res.getStatusCode() != 200) {
            throw new CalloutException('Failed to fetch products: ' + res.getBody());
        }

        List<Object> jsonList = (List<Object>) JSON.deserializeUntyped(res.getBody());
        List<KPN_ProductWrapper> products = new List<KPN_ProductWrapper>();

        for (Object obj : jsonList) {
            Map<String, Object> mapObj = (Map<String, Object>) obj;
            KPN_ProductWrapper p = new KPN_ProductWrapper(mapObj);
            products.add(p);
        }
        System.debug('products:'+products);
        return products;
    }
}