@IsTest
public with sharing class KPN_IntegrationsBase_Test {
     @IsTest
    static void testSendRequest() {
        Test.setMock(HttpCalloutMock.class, new KPN_MockHttpResponse(200, '{"status":"OK"}'));
        HttpResponse res = KPN_IntegrationsBase.sendRequest('GET', 'callout:Test_Endpoint', null);
        System.assertEquals(200, res.getStatusCode());
        System.assert(res.getBody().contains('OK'));
    }
}