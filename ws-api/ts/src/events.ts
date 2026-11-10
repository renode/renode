// Copyright (c) 2026 Antmicro <www.antmicro.com>
//
// SPDX-License-Identifier: Apache-2.0

export const UartOpened = 'uart-opened';
export const CanOpened = 'can-opened';
export const RenodeQuitted = 'renode-quitted';
export const ClearCommand = 'clear-command';

export interface UartOpenedArgs {
  name: string;
  machineName: string;
}
export type UartOpenedCallback = (event: UartOpenedArgs) => void;

export interface CanOpenedArgs {
  port: number;
  hubName: string;
}
export type CanOpenedCallback = (event: CanOpenedArgs) => void;

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

export const DisplayOpened = 'display-opened';
export interface DisplayOpenedArgs {
  name: string;
  machineName: string;
}
export type DisplayOpenedCallback = (event: DisplayOpenedArgs) => void;

export const SpiOpened = 'spi-opened';
export interface SpiOpenedArgs {
  name: string;
  machineName: string;
}
export type SpiOpenedCallback = (event: SpiOpenedArgs) => void;
