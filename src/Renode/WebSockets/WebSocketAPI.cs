//
// Copyright (c) 2010-2025 Antmicro
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
        public WebSocketAPI(string workingDir)
        {
            locker = new object();
            isDisposed = false;
            isRunning = false;
            workingDirName = workingDir;

            actionHandlers = new Dictionary<string, (IWebSocketAPIProvider, List<ActionHandler>)>();
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

            isRunning = true;
            return true;
        }

        public void Dispose()
        {
            if(isDisposed || !isRunning)
            {
                return;
            }

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

            SharedData.NewClientConnection?.Invoke();
        }

        private void OnClientDisconnect(WebSocketConnection sender)
        {
            if(sender != SharedData.MainConnection)
            {
                return;
            }

            SharedData.ClearEmulationEvent?.Invoke();

            foreach(var endp in new List<string> { "/telnet/29169", "/telnet/29170" })
            {
                foreach(var conn in WebSocketsManager.Instance.GetConnections(endp))
                {
                    conn.Dispose();
                }
            }
        }

        private void ClearEmulation()
        {
            EmulationManager.Instance.Clear();
            Recorder.Instance.ClearEvents();
            SharedData.SetDefaults();
        }

        private void RegisterType(Type t)
        {
            if(!typeof(IWebSocketAPIProvider).IsAssignableFrom(t) || t.IsAbstract)
            {
                return;
            }

            Logger.Log(LogLevel.Info, $"Found new API Provider: {t.Name}");
            IWebSocketAPIProvider apiProviderInstance = (IWebSocketAPIProvider)Activator.CreateInstance(t);
            apiProviders.Add(apiProviderInstance);

            foreach(var methodAttr in t.GetMethodsWithAttribute<WebSocketAPIActionAttribute>())
            {
                if(methodAttr.Method.ReturnType != typeof(WebSocketAPIResponse))
                {
                    continue;
                }

                List<ActionHandler> handlerList = null;
                if(actionHandlers.TryGetValue(methodAttr.Attribute.Name, out var existingHandlers))
                {
                    handlerList = existingHandlers.entries;
                }
                else
                {
                    var newHandlers = new List<ActionHandler>();
                    actionHandlers.Add(methodAttr.Attribute.Name, (apiProviderInstance, newHandlers));
                    handlerList = newHandlers;
                }

                if(handlerList.Where(h => h.Version == methodAttr.Attribute.Version).Count() != 0)
                {
                    continue;
                }

                Logger.Log(LogLevel.Info, $"- Registered action handler: {methodAttr.Method.Name} for: {methodAttr.Attribute.Name}");
                handlerList.Add(new ActionHandler
                {
                    Action = methodAttr.Method,
                    Version = methodAttr.Attribute.Version
                });
            }

            var handleEventsMethod = GetType().GetMethod(nameof(HandleEvents), BindingFlags.NonPublic | BindingFlags.Instance);
            foreach(var delegateField in t.GetFields(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance))
            {
                var eventAttr = delegateField.GetCustomAttribute<WebSocketAPIEventAttribute>();

                if(eventAttr == null)
                {
                    continue;
                }

                WebSocketAPIEventHandler eventHandler = (object data) => this.HandleEvents(eventAttr.Version.ToString(), eventAttr.Name, data);

                delegateField.SetValue(apiProviderInstance, eventHandler);
                Logger.Log(LogLevel.Info, $"- Registered event handler: {delegateField.Name} for: {eventAttr.Name}");
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
            catch(Exception)
            {
                SendErrorMessage(DefaultVersion, -1);
                return;
            }

            if(actionHandlers.TryGetValue(apiRequest.Action, out var handlers))
            {
                var actionHandler = handlers.entries.Where(h => h.Version <= apiRequest.Version)?.OrderBy(h => h.Version)?.First();

                if(actionHandler == null)
                {
                    Logger.Log(LogLevel.Warning, "WebSocketAPI ERROR: Requested too old version of action");
                    return;
                }

                var handlerParams = actionHandler.Action.GetParameters();
                var callArgs = new object[handlerParams.Length];

                int arg = 0;

                try
                {
                    foreach(var param in handlerParams)
                    {
                        callArgs[arg] = apiRequest.Payload[param.Name]?.ToObject(param.ParameterType);
                        arg++;
                    }
                }
                catch(Exception)
                {
                    SendErrorMessage(apiRequest.Version.ToString(), apiRequest.Id);
                    return;
                }

                var result = actionHandler.Action.Invoke(handlers.handlerInstance, callArgs);
                var handlerResponse = (result as WebSocketAPIResponse);
                var apiResponse = new APIResponse
                {
                    Version = apiRequest.Version.ToString(),
                    Status = handlerResponse.Error == null ? "success" : "fail",
                    Id = apiRequest.Id,
                    Data = handlerResponse.Data,
                    Error = handlerResponse.Error
                };

                var serializedResponse = JsonConvert.SerializeObject(apiResponse);
                Logger.Log(LogLevel.Debug, $"Sending response: {serializedResponse.ToString()}");
                SharedData.CurrentConnection.Send(Encoding.UTF8.GetBytes(serializedResponse));
            }
            else
            {
                Logger.Log(LogLevel.Warning, $"WebSocketAPI ERROR: Requested unknown action - {apiRequest.Action}");
            }
        }

        private void HandleEvents(string version, string eventName, object data)
        {
            var eventResponse = new APIEvent
            {
                Version = version,
                EventName = eventName,
                Data = data
            };

            var serializedEvent = JsonConvert.SerializeObject(eventResponse);

            Logger.Log(LogLevel.Debug, $"Event raised: {serializedEvent.ToString()}");
            SharedData.MainConnection?.Send(Encoding.UTF8.GetBytes(serializedEvent));
        }

        private void SendErrorMessage(string version, int id)
        {
            var apiResponse = new APIResponse
            {
                Version = version,
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
        private readonly Dictionary<string, (IWebSocketAPIProvider handlerInstance, List<ActionHandler> entries)> actionHandlers;
        private readonly List<IWebSocketAPIProvider> apiProviders;
        private static readonly string DefaultVersion = "1.5.0";

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
            public Version Version;
        }
    }
}