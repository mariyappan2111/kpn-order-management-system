@IsTest
global class KPN_MockHttpResponse implements HttpCalloutMock {
    private Integer status;
    private String body;

    public KPN_MockHttpResponse(Integer statusCode, String responseBody) {
        status = statusCode;
        body = responseBody;
    }

    global HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(status);
        res.setBody(body);
        return res;
    }
}