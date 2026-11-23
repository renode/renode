// Copyright (c) 2026 Antmicro <www.antmicro.com>
//
// SPDX-License-Identifier: Apache-2.0

import * as semver from 'semver';
import { version as packageVersion } from '../package.json';

export const version: string = packageVersion;
export const clientVersion: semver.SemVer = semver.parse(version)!;

export const isServerCompatible = (val: string): boolean => {
  const serverVersion = semver.parse(val);
  return (
    serverVersion?.major == clientVersion.major &&
    serverVersion.minor >= clientVersion.minor
  );
};
