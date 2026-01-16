// Copyright (c) 2026 Antmicro <www.antmicro.com>
//
// SPDX-License-Identifier: Apache-2.0

export class Peripheral {
  public constructor(
    public readonly machine: string,
    public readonly name: string,
  ) {}
}
