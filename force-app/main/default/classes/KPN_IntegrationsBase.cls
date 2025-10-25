public Virtual class KPN_IntegrationsBase {
    
    public static HttpResponse sendRequest(String method, String endpoint, String body) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod(method);
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(120000);
        if (body != null) req.setBody(body);
        return http.send(req);
    }
}