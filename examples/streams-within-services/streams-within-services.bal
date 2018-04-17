import ballerina/http;
import ballerina/mime;
import ballerina/io;

type ClientRequest {
    string host;
};

type RequestCount {
    string host;
    int count;
};

stream<ClientRequest> requestStream;

function initRealtimeRequestCounter () {

    stream<RequestCount> requestCountStream;

    //Whenever the `requestCountStream` receives an event from the streaming rules defined in the `forever` block,
    //the `printRequestCount` function is invoked.
    requestCountStream.subscribe(printRequestCount);

    //Gather all the events that are coming to the `requestStream` for 5 seconds, then, group by host and count the number
    //of requests per host. Next, check if the count is more than 6. If so, publish the output (host and the count) to the
    //`requestCountStream`. This `forever` block will be executed once when initializing the service. Therefore, each time the
    //`requestStream` receives an event, the processing will happen asynchronously.
    forever {
        from requestStream
        window timeBatch(5000)
        select host, count(host) as count group by host having count > 6
        => (RequestCount [] counts) {
                //'counts' are the output of the streaming rules and those are published to requestCountStream.
                // The `select` clause should match the structure of the `RequestCount` struct.
                requestCountStream.publish(counts);
        }
    }
}

function printRequestCount (RequestCount reqCount) {
    io:println("ALERT!! : Received more than 6 requests from the host within 5 seconds: " + reqCount.host);
}

endpoint http:Listener storeServiceEndpoint {
    port:9090
};

@http:ServiceConfig {
    basePath:"/"
}
service StoreService bind storeServiceEndpoint {

    future ftr = start initRealtimeRequestCounter();

    @http:ResourceConfig {
        methods:["POST"],
        path:"/requests"
    }
    requests (endpoint conn, http:Request req) {
        string hostName = untaint req.getHeader("Host");
        ClientRequest clientRequest = {host : hostName};
        requestStream.publish(clientRequest);

        http:Response res = new;
        res.setJsonPayload("{'message' : 'request successfully received'}");
        _ = conn -> respond(res);
    }
}

