//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text;

using Antmicro.Renode.Core;
using Antmicro.Renode.Logging;
using Antmicro.Renode.RobotFramework;
using Antmicro.Renode.Utilities;

using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace Antmicro.Renode.WebSockets
{
    public class WebSocketAPI : IDisposable
    {
        public static string Version = "1.9.0";

        public WebSocketAPI(string workingDir)
        {
            locker = new object();
            isDisposed = false;
            isRunning = false;
            workingDirName = workingDir;
            streamProxy = new WebSocketStreamProxy();

            apiProviders = new List<IWebSocketAPIProvider>();
            TypeManager.Instance.AutoLoadedType += RegisterType;

            webSocketServerProvider = new WebSocketServerProvider("/proxy", true);
            webSocketServerProvider.DataBlockReceived += ReceiveData;
            webSocketServerProvider.NewConnection += OnNewClientConnection;
            webSocketServerProvider.Disconnected += OnClientDisconnect;
        }

        public bool Start()
        {
            if(isDisposed || isRunning)
            {
                return false;
            }

            if(!TemporaryFilesManager.Instance.TryCreateDirectory(workingDirName, out var workDirTempPath))
            {
                return false;
            }

            SharedData = new WebSocketAPISharedData(workDirTempPath);
            SharedData.ClearEmulationEvent += ClearEmulation;

            if(!webSocketServerProvider.Start())
            {
                return false;
            }

            foreach(var apiProvider in apiProviders)
            {
                if(!apiProvider.Start(SharedData))
                {
                    return false;
                }
            }

            streamProxy.Start();

            isRunning = true;
            return true;
        }

        public void Dispose()
        {
            if(isDisposed || !isRunning)
            {
                return;
            }

            streamProxy.Dispose();

            isDisposed = true;
            webSocketServerProvider.Dispose();
            webSocketServerProvider = null;
        }

        private void OnNewClientConnection(WebSocketConnection sender, List<string> extraSegments)
        {
            var extraSegmentsCount = extraSegments.Count();

            if(extraSegmentsCount >= 1)
            {
                var newPath = Path.Combine(SharedData.Cwd.DefaultValue, extraSegments[0]);
                Directory.CreateDirectory(newPath);
                SharedData.Cwd.Value = newPath;
            }

            SharedData.MainConnection ??= sender;
            SharedData.NewClientConnection?.Invoke();
        }

        private void OnClientDisconnect(WebSocketConnection sender)
        {
            if(sender != SharedData.MainConnection)
            {
                return;
            }

            SharedData.ClearEmulationEvent?.Invoke();

            foreach(var endp in new List<string> { "/monitor", "/logs" })
            {
                foreach(var conn in WebSocketsManager.Instance.GetConnections(endp))
                {
                    conn.Dispose();
                }
            }

            SharedData.MainConnection = null;
        }

        private void ClearEmulation()
        {
            EmulationManager.Instance.Clear();
            Recorder.Instance.ClearEvents();
        }

        private void RegisterType(Type t)
        {
            if(!typeof(IWebSocketAPIProvider).IsAssignableFrom(t) || t.IsAbstract)
            {
                return;
            }

            Logger.Log(LogLevel.Debug, $"Found new API Provider: {t.Name}");
            var apiProviderInstance = (IWebSocketAPIProvider)Activator.CreateInstance(t);
            apiProviders.Add(apiProviderInstance);

            foreach(var methodAttr in t.GetMethodsWithAttribute<WebSocketAPIActionAttribute>())
            {
                if(methodAttr.Method.ReturnType != typeof(WebSocketAPIResponse))
                {
                    continue;
                }

                if(actionHandlers.ContainsKey(methodAttr.Attribute.Name))
                {
                    Logger.Log(LogLevel.Error, "WS-API: Multiple handlers found for '{0}' action", methodAttr.Attribute.Name);
                    continue;
                }

                actionHandlers.Add(methodAttr.Attribute.Name, (apiProviderInstance, new ActionHandler { Action = methodAttr.Method }));
                Logger.Log(LogLevel.Debug, $"- Registered action handler: {methodAttr.Method.Name} for: {methodAttr.Attribute.Name}");
            }

            var handleEventsMethod = GetType().GetMethod(nameof(HandleEvents), BindingFlags.NonPublic | BindingFlags.Instance);
            foreach(var delegateField in t.GetFields(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance))
            {
                var eventAttr = delegateField.GetCustomAttribute<WebSocketAPIEventAttribute>();

                if(eventAttr == null)
                {
                    continue;
                }

                WebSocketAPIEventHandler eventHandler = (object data) => this.HandleEvents(eventAttr.Name, data);

                delegateField.SetValue(apiProviderInstance, eventHandler);
                Logger.Log(LogLevel.Debug, $"- Registered event handler: {delegateField.Name} for: {eventAttr.Name}");
            }
        }

        private void ReceiveData(WebSocketConnection sender, byte[] data)
        {
            lock(locker)
            {
                SharedData.CurrentConnection = sender;
                HandleRequest(data);
                SharedData.CurrentConnection = null;
            }
        }

        private void HandleRequest(byte[] data)
        {
            string request = System.Text.Encoding.UTF8.GetString(data);
            Logger.Log(LogLevel.Debug, $"Received request: {request}");
            APIRequest apiRequest = null;

            try
            {
                apiRequest = JsonConvert.DeserializeObject<APIRequest>(request);
            }
            catch(Exception ex)
            {
                SendErrorMessage(-1);
                Logger.Log(LogLevel.Error, "Failed to parse request: {0}", ex);
                return;
            }

            if(!actionHandlers.TryGetValue(apiRequest.Action, out var handler))
            {
                Logger.Log(LogLevel.Warning, "WebSocketAPI ERROR: Requested unknown action - {0}", apiRequest.Action);
                return;
            }

            var handlerParams = handler.action.Action.GetParameters();
            var callArgs = new object[handlerParams.Length];

            var arg = 0;
            try
            {
                foreach(var param in handlerParams)
                {
                    callArgs[arg] = apiRequest.Payload[param.Name]?.ToObject(param.ParameterType);
                    arg++;
                }
            }
            catch(Exception ex)
            {
                Logger.Log(LogLevel.Error, "Failed to prepare request arguments: {0}", ex);
                SendErrorMessage(apiRequest.Id);
                return;
            }

            var result = handler.action.Action.Invoke(handler.instance, callArgs);
            var handlerResponse = (result as WebSocketAPIResponse);
            var apiResponse = new APIResponse
            {
                Version = Version,
                Status = handlerResponse.Error == null ? "success" : "failure",
                Id = apiRequest.Id,
                Data = handlerResponse.Data,
                Error = handlerResponse.Error
            };

            var serializedResponse = JsonConvert.SerializeObject(apiResponse);
            Logger.Log(LogLevel.Debug, "Sending response: {0}", serializedResponse);
            SharedData.CurrentConnection.Send(Encoding.UTF8.GetBytes(serializedResponse));
        }

        private void HandleEvents(string eventName, object data)
        {
            var eventResponse = new APIEvent
            {
                Version = Version,
                EventName = eventName,
                Data = data
            };

            var serializedEvent = JsonConvert.SerializeObject(eventResponse);

            Logger.Log(LogLevel.Debug, $"Event raised: {serializedEvent.ToString()}");
            webSocketServerProvider.Broadcast(Encoding.UTF8.GetBytes(serializedEvent));
        }

        private void SendErrorMessage(int id)
        {
            var apiResponse = new APIResponse
            {
                Version = Version,
                Id = id,
                Status = "fail"
            };

            var serializedResponse = JsonConvert.SerializeObject(apiResponse);
            SharedData.CurrentConnection.Send(Encoding.UTF8.GetBytes(serializedResponse));
        }

        private bool isDisposed;
        private bool isRunning;
        private WebSocketAPISharedData SharedData;
        private WebSocketServerProvider webSocketServerProvider;
        private readonly string workingDirName;
        private readonly object locker;
        private readonly Dictionary<string, (IWebSocketAPIProvider instance, ActionHandler action)> actionHandlers = new();
        private readonly List<IWebSocketAPIProvider> apiProviders;
        private readonly WebSocketStreamProxy streamProxy;

        private class APIRequest
        {
            // 649:  Field '...' is never assigned to, and will always have its default value null
#pragma warning disable 649
            [JsonProperty("action", Required = Required.Always)]
            public string Action;

            [JsonProperty("payload", Required = Required.Always)]
            public JToken Payload;

            [JsonProperty("version", Required = Required.Always)]
            public Version Version;

            [JsonProperty("id", Required = Required.Always)]
            public int Id;
#pragma warning restore 649
        }

        private class APIResponse
        {
            [JsonProperty("version", Required = Required.Always)]
            public string Version;

            [JsonProperty("status", Required = Required.Always)]
            public string Status;

            [JsonProperty("id", Required = Required.Always)]
            public int Id;

            [JsonProperty("data", Required = Required.AllowNull)]
            public object Data;

            [JsonProperty("error", Required = Required.AllowNull)]
            public string Error;
        }

        private class APIEvent
        {
            [JsonProperty("version", Required = Required.Always)]
            public string Version;

            [JsonProperty("event", Required = Required.Always)]
            public string EventName;

            [JsonProperty("data", Required = Required.AllowNull)]
            public object Data;
        }

        private class ActionHandler
        {
            public MethodInfo Action;
        }
    }
}
