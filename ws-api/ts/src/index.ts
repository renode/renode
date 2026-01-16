// Copyright (c) 2026 Antmicro <www.antmicro.com>
//
// SPDX-License-Identifier: Apache-2.0

import { version, isOutdatedClientVersion } from './version';
import { z } from 'zod';
import * as s from './schema';
import WebSocket from 'isomorphic-ws';
import { Buffer } from 'buffer';
import { tryConnectWs } from './utils';
import {
  UartOpened,
  UartOpenedCallback,
  UartOpenedArgs,
  RenodeQuitted,
  ClearCommand,
  LedStateChanged,
  LedStateChangedCallback,
  LedStateChangedArgs,
  ButtonStateChanged,
  ButtonStateChangedCallback,
  ButtonStateChangedArgs,
} from './events';
import {
  GetSensorValue,
  Sensor,
  SensorType,
  SensorTypeFromString,
  SensorValue,
} from './sensor';

export {
  Sensor,
  SensorType,
  SensorTypeFromString,
  GetSensorValue,
  SensorValue,
  EventCallback,
  EmptyEventCallback,
  UartOpenedArgs,
  UartOpenedCallback,
};

class SocketClosedEvent extends Event {
  constructor() {
    super('close');
  }
}

export class RenodeProxySession extends EventTarget {
  private requestHandlers: RequestHandlers = {};
  private eventHandlers: EventHandlers = {};
  private id: number = 1;
  private defaultTimeout: number = 60000; // in ms
  private errorCallback: (event: WebSocket.ErrorEvent) => void;

  public static async tryConnect(wsUri: string, workspace: string) {
    const uri = new URL(`/proxy/${workspace}`, wsUri);
    const socket = await tryConnectWs(uri.toString());
    return new RenodeProxySession(socket, wsUri);
  }

  public static fromWs(ws: WebSocket) {
    return new RenodeProxySession(ws);
  }

  private constructor(
    private sessionSocket: WebSocket,
    private sessionUri?: string,
  ) {
    super();
    this.errorCallback = _ =>
      console.error('RenodeProxySession: WebSocket error');
    this.sessionSocket.addEventListener('message', ev =>
      this.onData(ev.data.toString()),
    );
    this.sessionSocket.addEventListener('error', ev => this.errorCallback(ev));
    this.sessionSocket.addEventListener('close', () => this.onClose());
  }

  public set onError(cb: (event: WebSocket.ErrorEvent) => void) {
    this.errorCallback = cb;
  }

  public get sessionBase(): string | undefined {
    return this.sessionUri;
  }

  public get socketReady() {
    const state = this.sessionSocket.readyState ?? WebSocket.CLOSED;
    return state === WebSocket.OPEN;
  }

  public async startRenode(cwd?: string, gui: boolean = false): Promise<void> {
    await this.sendSessionRequestTyped(
      {
        action: 'spawn',
        payload: {
          name: 'renode',
          cwd,
          gui,
        },
      },
      s.SpawnResponse,
      10500, // ms
    );
  }

  public execMonitor(commands: string[]): Promise<void> {
    return this.sendSessionRequestTyped(
      {
        action: 'exec-monitor',
        payload: {
          commands,
        },
      },
      s.ExecMonitorResponse,
      10000, // ms
    );
  }

  public getUarts(machine: string) {
    return this.sendSessionRequestTyped(
      {
        action: 'exec-renode',
        payload: {
          command: 'uarts',
          args: { machine },
        },
      },
      s.GetUartsResponse,
    );
  }

  public async getButtons(machine: string) {
    return await this.sendSessionRequestTyped(
      {
        action: 'exec-renode',
        payload: {
          command: 'buttons',
          args: { machine },
        },
      },
      s.GetButtonsResponse,
    );
  }

  public async getLeds(machine: string) {
    return await this.sendSessionRequestTyped(
      {
        action: 'exec-renode',
        payload: {
          command: 'leds',
          args: { machine },
        },
      },
      s.GetLedsResponse,
    );
  }

  public async setButtonValue(
    machine: string,
    peripheral: string,
    value: boolean,
  ): Promise<void> {
    await this.sendSessionRequestTyped(
      {
        action: 'exec-renode',
        payload: {
          command: 'button-set',
          args: {
            machine: machine,
            peripheral: peripheral,
            value: value,
          },
        },
      },
      s.EmptyExecResponse,
    );
  }

  public getMachines() {
    return this.sendSessionRequestTyped(
      {
        action: 'exec-renode',
        payload: {
          command: 'machines',
        },
      },
      s.GetMachinesResponse,
    );
  }

  public async getSensors(
    machine: string,
    type?: SensorType,
  ): Promise<Sensor[]> {
    const sensorType = type === undefined ? {} : { type };
    const result = await this.sendSessionRequestTyped(
      {
        action: 'exec-renode',
        payload: {
          command: 'sensors',
          args: { machine, ...sensorType },
        },
      },
      s.GetSensorsResponse,
    );
    return result.map(
      entry =>
        new Sensor(
          machine,
          entry.name,
          entry.types.map(type => SensorTypeFromString(type)!),
        ),
    );
  }

  public async getSensorValue(
    sensor: Sensor,
    type: SensorType,
  ): Promise<SensorValue> {
    const result = await this.sendSessionRequestTyped(
      {
        action: 'exec-renode',
        payload: {
          command: 'sensor-get',
          args: { machine: sensor.machine, peripheral: sensor.name, type },
        },
      },
      s.GetSensorResponse,
    );
    return GetSensorValue(type, result);
  }

  public async setSensorValue(
    sensor: Sensor,
    type: SensorType,
    value: SensorValue,
  ): Promise<void> {
    await this.sendSessionRequestTyped(
      {
        action: 'exec-renode',
        payload: {
          command: 'sensor-set',
          args: {
            machine: sensor.machine,
            peripheral: sensor.name,
            type,
            value: value.sample,
          },
        },
      },
      s.EmptyExecResponse,
    );
  }

  public async stopRenode(): Promise<void> {
    await this.sendSessionRequestTyped(
      {
        action: 'kill',
        payload: {
          name: 'renode',
        },
      },
      s.KillResponse,
    );
  }

  public async fetchZipToFs(zipUrl: string) {
    return this.sendSessionRequestTyped(
      {
        action: 'fs/zip',
        payload: {
          args: [zipUrl],
        },
      },
      s.FsZipResponse,
    );
  }

  public async fetchFileToFs(fileUrl: string) {
    return this.sendSessionRequestTyped(
      {
        action: 'fs/fetch',
        payload: {
          args: [fileUrl],
        },
      },
      s.FsFetchResponse,
    );
  }

  public async downloadFile(path: string): Promise<Uint8Array> {
    const encoded = await this.sendSessionRequestTyped(
      {
        action: 'fs/dwnl',
        payload: {
          args: [path],
        },
      },
      s.FsDwnlResponse,
    );
    return Buffer.from(encoded, 'base64');
  }

  public async createDirectory(path: string): Promise<void> {
    await this.sendSessionRequestTyped(
      {
        action: 'fs/mkdir',
        payload: {
          args: [path],
        },
      },
      s.FsMkdirResponse,
    );
  }

  public sendFile(path: string, contents: Uint8Array) {
    const buf = Buffer.from(contents);
    const enc = buf.toString('base64');
    return this.sendSessionRequestTyped(
      {
        action: 'fs/upld',
        payload: {
          args: [path],
          data: enc,
        },
      },
      s.FsUpldResponse,
    );
  }

  public async listFiles(path: string) {
    return this.sendSessionRequestTyped(
      {
        action: 'fs/list',
        payload: {
          args: [path],
        },
      },
      s.FsListResponse,
    );
  }

  public statFile(path: string) {
    return this.sendSessionRequestTyped(
      {
        action: 'fs/stat',
        payload: {
          args: [path],
        },
      },
      s.FsStatResponse,
    );
  }

  public removeFile(path: string) {
    return this.sendSessionRequestTyped(
      {
        action: 'fs/remove',
        payload: {
          args: [path],
        },
      },
      s.FsRemoveResponse,
    );
  }

  public moveFile(from: string, to: string) {
    return this.sendSessionRequestTyped(
      {
        action: 'fs/move',
        payload: { args: [from, to] },
      },
      s.FsMoveResponse,
    );
  }

  public copyFile(from: string, to: string) {
    return this.sendSessionRequestTyped(
      {
        action: 'fs/copy',
        payload: { args: [from, to] },
      },
      s.FsCopyResponse,
    );
  }

  public replaceAnalyzers(path: string) {
    return this.sendSessionRequestTyped(
      {
        action: 'tweak/socket',
        payload: { args: [path] },
      },
      s.ReplaceAnalyzersResponse,
    );
  }

  public filterEvents(allowedEvents: string[]) {
    return this.sendSessionRequestTyped(
      {
        action: 'filter-events',
        payload: { args: allowedEvents },
      },
      s.FilterEventsResponse,
    );
  }

  public registerEventCallback(event: string, callback: EventCallback) {
    if (!this.eventHandlers[event]) {
      this.eventHandlers[event] = [];
    }
    this.eventHandlers[event].push(callback);
  }

  public unregisterEventCallback(
    event: string,
    callback: EventCallback,
  ): boolean {
    if (!this.eventHandlers[event]) {
      return false;
    }
    const index = this.eventHandlers[event].indexOf(callback);
    if (index == -1) {
      return false;
    }
    this.eventHandlers[event].splice(index, 1);
    return true;
  }

  public registerUartOpenedCallback(
    callback: UartOpenedCallback,
  ): EventCallback {
    const wrapped = (data: object) => {
      callback(data as UartOpenedArgs);
    };
    this.registerEventCallback(UartOpened, wrapped);
    return wrapped;
  }

  public unregisterUartOpenedCallback(callback: EventCallback): boolean {
    return this.unregisterEventCallback(UartOpened, callback);
  }

  public registerRenodeQuittedCallback(callback: EmptyEventCallback): void {
    this.registerEventCallback(RenodeQuitted, callback);
  }

  public unregisterRenodeQuittedCallback(
    callback: EmptyEventCallback,
  ): boolean {
    return this.unregisterEventCallback(RenodeQuitted, callback);
  }

  public registerClearCommandCallback(callback: EmptyEventCallback): void {
    this.registerEventCallback(ClearCommand, callback);
  }

  public unregisterClearCommandCallback(callback: EmptyEventCallback): boolean {
    return this.unregisterEventCallback(ClearCommand, callback);
  }

  public registerLedStateChangedCallback(
    callback: LedStateChangedCallback,
  ): EventCallback {
    const wrapped = (data: object) => {
      callback(data as LedStateChangedArgs);
    };
    this.registerEventCallback(LedStateChanged, wrapped);
    return wrapped;
  }

  public unregisterLedStateChangedCallback(callback: EventCallback): boolean {
    return this.unregisterEventCallback(LedStateChanged, callback);
  }

  public registerButtonStateChangedCallback(
    callback: ButtonStateChangedCallback,
  ): EventCallback {
    const wrapped = (data: object) => {
      callback(data as ButtonStateChangedArgs);
    };
    this.registerEventCallback(ButtonStateChanged, wrapped);
    return wrapped;
  }

  public unregisterButtonStateChangedCallback(
    callback: EventCallback,
  ): boolean {
    return this.unregisterEventCallback(ButtonStateChanged, callback);
  }

  public dispose() {
    this.sessionSocket.close();
  }

  // *** Event handlers ***

  private onData(data: string) {
    try {
      const obj: object = JSON.parse(data);
      if ('id' in obj && typeof obj.id === 'number') {
        this.onResponse(obj.id, obj);
      } else if ('event' in obj && typeof obj.event === 'string') {
        this.onEvent(obj.event, 'data' in obj ? (obj.data as object) : {});
      } else {
        console.error('RenodeProxySession: Received malformed packet', obj);
      }
    } catch {
      console.error('RenodeProxySession: Received malformed data', data);
    }
  }

  private onResponse(id: number, data: object) {
    const handler = this.requestHandlers[id];
    delete this.requestHandlers[id];
    if (handler) {
      handler(data);
    } else {
      console.error(
        'RenodeProxySession: Received response without request',
        data,
      );
    }
  }

  private onEvent(event: string, data: object) {
    if (!this.eventHandlers[event]) {
      console.error(
        `RenodeProxySession: Received event '${event}' with no listeners`,
        data,
      );
    } else {
      this.eventHandlers[event].forEach(handler => handler(data));
    }
  }

  private onClose() {
    Object.values(this.requestHandlers).forEach(handler =>
      handler?.(undefined, new Error('WebSocket closed')),
    );
    this.requestHandlers = {};
    this.eventHandlers = {};

    this.dispatchEvent(new SocketClosedEvent());
  }

  // *** Utilities ***

  private async sendSessionRequestTyped<Res extends s.Response>(
    req: PartialRequest,
    resParser: z.ZodType<Res, z.ZodTypeDef, object>,
    timeout?: number,
  ): Promise<ResData<Res>> {
    if (!this.socketReady) {
      throw new Error('Not connected');
    }

    const res: object = await this.sendInner(
      req,
      timeout ?? this.defaultTimeout,
    );
    console.debug('Got answer from session', res);

    const resParsed = await resParser.safeParseAsync(res);

    if (!resParsed.success) {
      throw resParsed.error;
    }

    const obj = resParsed.data as Res;
    if (obj.status !== 'success') {
      throw new Error(obj.error);
    }

    if (isOutdatedClientVersion(obj.version)) {
      throw new Error(
        `Protocol version (${obj.version}) is incompatible with the JS client (${version})`,
      );
    }

    return obj.data;
  }

  private sendInner(req: PartialRequest, timeout: number): Promise<object> {
    const id = this.id++;
    const msg = JSON.stringify({
      ...req,
      version,
      id,
    });
    let timeoutId: ReturnType<typeof setTimeout>;

    return Promise.race([
      new Promise<object>((resolve, reject) => {
        console.debug('Sending message to session', msg);

        if (this.sessionSocket) {
          this.requestHandlers[id] = (res, err) => {
            clearTimeout(timeoutId);
            if (err) {
              reject(err);
            } else {
              resolve(res!);
            }
          };
          this.sessionSocket.send(msg);
        } else {
          reject(new Error('Not connected'));
        }
      }),
      new Promise<object>(
        (_resolve, reject) =>
          (timeoutId = setTimeout(() => {
            delete this.requestHandlers[id];
            console.debug('Timeout for id', id);
            reject(new Error(`Request reached timeout after ${timeout}ms`));
          }, timeout)),
      ),
    ]);
  }
}

interface PartialRequest {
  action: string;
  payload: unknown;
}

// Helper to properly type response payload
type ResData<T> = T extends { status: 'success'; data?: infer U } ? U : never;

type RequestHandlers = { [key: number]: RequestCallback };
type RequestCallback = (response: object | undefined, error?: Error) => void;
type EventHandlers = { [key: string]: EventCallback[] };
type EventCallback = (event: object) => void;
type EmptyEventCallback = () => void;
