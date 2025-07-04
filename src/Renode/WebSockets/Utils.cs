using System;
using System.IO;

using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.WebSockets
{
    public class WebSocketAPIBaseAttribute : Attribute
    {
        public WebSocketAPIBaseAttribute(string name, string version)
        {
            Name = name;
            Version = new Version(version);
        }

        public string Name;
        public Version Version;
    }

    public class WebSocketAPIActionAttribute : WebSocketAPIBaseAttribute
    {
        public WebSocketAPIActionAttribute(string action, string version) : base(action, version)
        {
        }
    }

    public class WebSocketAPIEventAttribute : WebSocketAPIBaseAttribute
    {
        public WebSocketAPIEventAttribute(string eventName, string version) : base(eventName, version)
        {
        }
    }

    public enum WebSocketAPIResponseStatus
    {
        SUCCESS,
        FAIL
    }

    public class WebSocketAPIResponse
    {
        public object data;
        public string error;
    }

    public interface IWebSocketAPIProvider : IAutoLoadType
    {
        bool Start(WebSocketAPISharedData sharedData);
    }

    public delegate void WebSocketAPIEventHandler(object eventData);

    public static class WebSocketAPIUtils
    {
        public static WebSocketAPIResponse CreateActionResponse(object response, string errorMessage = null)
        {
            return new WebSocketAPIResponse
            {
                data = response,
                error = errorMessage
            };
        }

        public static WebSocketAPIResponse CreateEmptyActionResponse(string errorMessage = null)
        {
            return new WebSocketAPIResponse
            {
                data = new object(),
                error = errorMessage
            };
        }

        public static void RaiseEvent(this WebSocketAPIEventHandler webSocketEvent, object data)
        {
            webSocketEvent.Invoke(data);
        }

        public static void RaiseEventWithoutBody(this WebSocketAPIEventHandler webSocketEvent)
        {
            webSocketEvent.Invoke(new object());
        }
    }

    public class WebSocketAPISharedData
    {
        public WebSocketAPISharedData(string cwd)
        {
            this.Cwd = new DefaultVariable<string>(cwd);
        }

        public void SetDefaults()
        {
            Cwd.SetDefault();
        }

        public WebSocketConnection CurrentConnection;
        public WebSocketConnection MainConnection;
        public Action ClearEmulationEvent;
        public Action NewClientConnection;
        public readonly DefaultVariable<string> Cwd;

        public class DefaultVariable<T>
        {
            public DefaultVariable(T defaultValue)
            {
                DefaultValue = defaultValue;
                Value = defaultValue;
            }

            public void SetDefault()
            {
                Value = DefaultValue;
            }

            public T Value;
            public readonly T DefaultValue;
        }
    }
}