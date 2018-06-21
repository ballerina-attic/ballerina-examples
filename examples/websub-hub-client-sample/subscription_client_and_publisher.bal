// The Ballerina Main program that demonstrates a) a publisher that brings up the internal Ballerina Hub,
// registers a topic at the hub, and publishes updates to the topic and b) the usage of the Hub client endpoint to
// subscribe/unsubscribe to notifications.
import ballerina/io;
import ballerina/runtime;
import ballerina/websub;

function main(string... args) {
    // The worker that starts up the WebSub Hub, registers a topic and publishes updates against the topic
    worker publisher {
        runPublisher();
    }

    // The worker that explicitly sends subscription change requests to the hub, for the started up WebSub subscriber
    //service
    worker subscriptionChangeClient {
        runSubscriptionChangeClient();
    }
}

// The function representing WebSub Hub and Publisher functionality
function runPublisher() {
    // Start up the internal Ballerina Hub.
    io:println("Starting up the Ballerina Hub Service");
    websub:WebSubHub webSubHub = websub:startUpBallerinaHub(port = 9191) but {
        websub:HubStartedUpError hubStartedUpErr => hubStartedUpErr.startedUpHub
    };

    // Register a topic at the hub.
    var registrationResponse = webSubHub.registerTopic(
                                            "http://websubpubtopic.com");
    match (registrationResponse) {
        error webSubError => io:println("Error occurred registering topic: "
                + webSubError.message);
        () => io:println("Topic registration successful!");
    }

    // Make the publisher wait until the subscriber subscribes at the hub.
    runtime:sleep(10000);

    // Publish directly to the internal Ballerina Hub.
    var publishResponse = webSubHub.publishUpdate("http://websubpubtopic.com",
        { "action": "publish", "mode": "internal-hub" });
    match (publishResponse) {
        error webSubError => io:println("Error notifying hub: "
                + webSubError.message);
        () => io:println("Update notification successful!");
    }

    // Make the publisher wait until the subscriber unsubscribes at the hub.
    runtime:sleep(10000);

    // Publish directly to the internal Ballerina Hub.
    publishResponse = webSubHub.publishUpdate("http://websubpubtopic.com",
        { "action": "publish", "mode": "internal-hub" });
    match (publishResponse) {
        error webSubError => io:println("Error notifying hub: "
                + webSubError.message);
        () => io:println("Update notification successful!");
    }

    // Make the publisher wait until notification is done to subscribers.
    runtime:sleep(5000);
}

// This is the remote WebSub Hub Endpoint to which subscription and unsubscription requests are sent.
endpoint websub:Client websubHubClientEP {
    url: "https://localhost:9191/websub/hub"
};

// The function representing the usage of the WebSub Hub Client Endpoint to subscribe/unsubscribe at a hub
function runSubscriptionChangeClient() {

    // Send the subscription request for the subscriber service.
    websub:SubscriptionChangeRequest subscriptionRequest = {
        topic: "http://websubpubtopic.com",
        callback: "http://localhost:8181/websub",
        secret: "Kslk30SNF2AChs2"
    };

    var response = websubHubClientEP->subscribe(subscriptionRequest);

    match (response) {
        websub:SubscriptionChangeResponse subscriptionChangeResponse => {
            io:println("Subscription Request successful at Hub ["
                    + subscriptionChangeResponse.hub + "] for Topic ["
                    + subscriptionChangeResponse.topic + "]");
        }
        error e => {
            io:println("Error occurred with Subscription Request: ", e);
        }
    }

    // Wait for the initial notification, before unsubscribing.
    runtime:sleep(10000);

    // Send unsubscription request for the subscriber service.
    websub:SubscriptionChangeRequest unsubscriptionRequest = {
        topic: "http://websubpubtopic.com",
        callback: "http://localhost:8181/websub"
    };

    response = websubHubClientEP->unsubscribe(unsubscriptionRequest);

    match (response) {
        websub:SubscriptionChangeResponse subscriptionChangeResponse => {
            io:println("Unsubscription Request successful at Hub ["
                    + subscriptionChangeResponse.hub
                    + "] for Topic [" + subscriptionChangeResponse.topic + "]");
        }
        error e => {
            io:println("Error occurred with Unsubscription Request: ", e);
        }
    }

    // Confirm unsubscription - no notifications should be received.
    runtime:sleep(5000);
}
