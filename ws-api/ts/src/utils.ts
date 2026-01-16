// Copyright (c) 2026 Antmicro <www.antmicro.com>
//
// SPDX-License-Identifier: Apache-2.0

import WebSocket from 'isomorphic-ws';

export function tryJsonParse(input: string): object | string {
  try {
    return JSON.parse(input);
  } catch {
    return input;
  }
}

export function tryConnectWs(uri: string): Promise<WebSocket> {
  return new Promise<WebSocket>((resolve, reject) => {
    const socket = new WebSocket(uri);

    socket.addEventListener('open', () => resolve(socket), { once: true });
    socket.addEventListener(
      'error',
      () => reject(new Error('Error while connecting')),
      { once: true },
    );
    socket.addEventListener(
      'close',
      () => reject(new Error('Could not connect')),
      { once: true },
    );
  });
}
