namespace Antmicro.Renode.WebSockets.Providers
{
    public class EventSubcriptionProvider : IWebSocketAPIProvider
    {
        public bool Start(WebSocketAPISharedData sharedData)
        {
            SharedData = sharedData;
            return true;
        }

        [WebSocketAPIAction("subscribe", "1.5.0")]
        private WebSocketAPIResponse Subscribe(string eventName)
        {
            if(SharedData.EventSubscriptions.TryGetValue(eventName, out var subscriptions))
            {
                var connection = SharedData.CurrentConnection;
                if(subscriptions.Contains(connection))
                {
                    return WebSocketAPIUtils.CreateEmptyActionResponse("Connection already subscribed");
                }
                else
                {
                    subscriptions.Add(connection);
                    return WebSocketAPIUtils.CreateEmptyActionResponse();
                }
            }
            else
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse("Unknown event");
            }
        }

        [WebSocketAPIAction("unsubscribe", "1.5.0")]
        private WebSocketAPIResponse Unsubscribe(string eventName)
        {
            if(SharedData.EventSubscriptions.TryGetValue(eventName, out var subscriptions))
            {
                var connection = SharedData.CurrentConnection;
                if(subscriptions.Remove(connection))
                {
                    return WebSocketAPIUtils.CreateEmptyActionResponse();
                }
                else
                {
                    return WebSocketAPIUtils.CreateEmptyActionResponse("Connection not subscribed");
                }
            }
            else
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse("Unknown event");
            }
        }

        private WebSocketAPISharedData SharedData;
    }
}