// Copyright (c) 2026 Antmicro <www.antmicro.com>
//
// SPDX-License-Identifier: Apache-2.0

export const UartOpened = 'uart-opened';
export const RenodeQuitted = 'renode-quitted';
export const ClearCommand = 'clear-command';

export interface UartOpenedArgs {
  port: number;
  name: string;
  machineName: string;
}
export type UartOpenedCallback = (event: UartOpenedArgs) => void;

export const LedStateChanged = 'led-state-changed';
export interface LedStateChangedArgs {
  machineName: string;
  name: string;
  value: boolean;
}
export type LedStateChangedCallback = (event: LedStateChangedArgs) => void;

export const ButtonStateChanged = 'button-state-changed';
export interface ButtonStateChangedArgs {
  machineName: string;
  name: string;
  value: boolean;
}
export type ButtonStateChangedCallback = (
  event: ButtonStateChangedArgs,
) => void;
