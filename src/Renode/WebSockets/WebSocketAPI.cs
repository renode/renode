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
            alreadyDisposed = false;
            SharedData = new WebSocketAPISharedData();
            SharedData.cwd = Path.Combine(Environment.CurrentDirectory, workingDir);

            if(!Directory.Exists(SharedData.cwd))
            {
                Directory.CreateDirectory(SharedData.cwd);
            }

            actionHandlers = new Dictionary<string, (object, List<ActionHandler>)>();
            TypeManager.Instance.AutoLoadedType += RegisterType;

            webSocketServerProvider = new WebSocketServerProvider(false, "/proxy");
            webSocketServerProvider.DataBlockReceived += HandleRequest;
            webSocketServerProvider.NewConnection += OnNewClientConnection;
            webSocketServerProvider.Disconnected += OnClientDisconnect;
        }

        public void Dispose()
        {
            if(alreadyDisposed)
            {
                return;
            }

            alreadyDisposed = true;
            webSocketServerProvider.Dispose();
            webSocketServerProvider = null;
        }

        private void OnNewClientConnection(List<string> extraSegments)
        {
            var extraSegmentsCount = extraSegments.Count();

            if(extraSegmentsCount >= 1)
            {
                SetCwd("working-dir/" + extraSegments[0]);
            }
        }

        private void OnClientDisconnect()
        {
            EmulationManager.Instance.Clear();
            Recorder.Instance.ClearEvents();
            SharedData.SetDefaults();
        }

        private void SetCwd(string newCwd)
        {
            var cwd = Path.Combine(Environment.CurrentDirectory, newCwd);
            Directory.CreateDirectory(cwd);

            SharedData.cwd = cwd;
        }

        private void RegisterType(Type t)
        {
            if(!typeof(IWebSocketAPIProvider).IsAssignableFrom(t) || t.IsAbstract)
            {
                return;
            }

            Logger.Log(LogLevel.Info, $"Found new API Provider: {t.Name}");
            object apiProviderInstance = Activator.CreateInstance(t, new[] { SharedData });

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

                if(handlerList.Where(h => h.version == methodAttr.Attribute.Version).Count() != 0)
                {
                    continue;
                }

                Logger.Log(LogLevel.Info, $"- Registered action handler: {methodAttr.Method.Name} for: {methodAttr.Attribute.Name}");
                handlerList.Add(new ActionHandler
                {
                    action = methodAttr.Method,
                    version = methodAttr.Attribute.Version
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

        private void HandleRequest(byte[] data)
        {
            string request = System.Text.Encoding.UTF8.GetString(data);
            Logger.Log(LogLevel.Debug, $"\tReceived request: {request}");
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
            
            if(actionHandlers.TryGetValue(apiRequest.action, out var handlers))
            {
                var actionHandler = handlers.entries.Where(h => h.version <= apiRequest.version)?.OrderBy(h => h.version)?.First();

                if(actionHandler == null)
                {
                    Logger.Log(LogLevel.Warning, "WebSocketAPI ERROR: Requested too old version of action");
                    return;
                }

                var handlerParams = actionHandler.action.GetParameters();
                var callArgs = new object[handlerParams.Length];

                int arg = 0;

                try
                {
                    foreach(var param in handlerParams)
                    {
                        callArgs[arg] = apiRequest.payload[param.Name].ToObject(param.ParameterType);
                        arg++;
                    }
                }
                catch(Exception)
                {
                    SendErrorMessage(apiRequest.version.ToString(), apiRequest.id);
                    return;
                }

                var result = actionHandler.action.Invoke(handlers.handlerInstance, callArgs);
                var handlerResponse = (result as WebSocketAPIResponse);
                var apiResponse = new APIResponse
                {
                    version = apiRequest.version.ToString(),
                    status = handlerResponse.error == null ? "success" : "fail",
                    id = apiRequest.id,
                    data = handlerResponse.data,
                    error = handlerResponse.error
                };

                var serializedResponse = JsonConvert.SerializeObject(apiResponse);
                Logger.Log(LogLevel.Debug, $"\tSending response: {serializedResponse.ToString()}\n");
                webSocketServerProvider.Send(Encoding.UTF8.GetBytes(serializedResponse));
            }
            else
            {
                Logger.Log(LogLevel.Warning, $"WebSocketAPI ERROR: Requested unknown action - {apiRequest.action}");
            }
        }

        private void HandleEvents(string version, string eventName, object data)
        {
            var eventResponse = new APIEvent
            {
                version = version,
                eventName = eventName,
                data = data
            };

            var serializedEvent = JsonConvert.SerializeObject(eventResponse);

            Logger.Log(LogLevel.Debug, $"\tEvent raised: {serializedEvent.ToString()}");
            webSocketServerProvider.Send(Encoding.UTF8.GetBytes(serializedEvent));
        }

        private void SendErrorMessage(string version, int id)
        {
            var apiResponse = new APIResponse
            {
                version = version,
                id = id,
                status = "fail"
            };

            var serializedResponse = JsonConvert.SerializeObject(apiResponse);
            webSocketServerProvider.Send(Encoding.UTF8.GetBytes(serializedResponse));
        }

        private bool alreadyDisposed;
        private WebSocketServerProvider webSocketServerProvider;
        private readonly WebSocketAPISharedData SharedData;
        private readonly Dictionary<string, (object handlerInstance, List<ActionHandler> entries)> actionHandlers;
        private static readonly string DefaultVersion = "1.5.0";

        private class APIRequest
        {
            [JsonProperty("action", Required = Required.Always)]
            public string action;

            [JsonProperty("payload", Required = Required.Always)]
            public JToken payload;

            [JsonProperty("version", Required = Required.Always)]
            public Version version;

            [JsonProperty("id", Required = Required.Always)]
            public int id;
        }

        private class APIResponse
        {
            [JsonProperty("version", Required = Required.Always)]
            public string version;

            [JsonProperty("status", Required = Required.Always)]
            public string status;

            [JsonProperty("id", Required = Required.Always)]
            public int id;

            [JsonProperty("data", Required = Required.AllowNull)]
            public object data;

            [JsonProperty("error", Required = Required.AllowNull)]
            public string error;
        }

        private class APIEvent
        {
            [JsonProperty("version", Required = Required.Always)]
            public string version;

            [JsonProperty("event", Required = Required.Always)]
            public string eventName;

            [JsonProperty("data", Required = Required.AllowNull)]
            public object data;
        }

        private class ActionHandler
        {
            public MethodInfo action;
            public Version version;
        }
    }
}