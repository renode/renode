// Copyright (c) 2026 Antmicro <www.antmicro.com>
//
// SPDX-License-Identifier: Apache-2.0

import * as semver from 'semver';
import { version as packageVersion } from '../package.json';

export const version: string = packageVersion;
export const clientVersion: semver.SemVer = semver.parse(version)!;

export const isOutdatedClientVersion = (val: string): boolean => {
  const apiVersion = semver.parse(val);
  return (
    apiVersion?.major != clientVersion.major ||
    apiVersion.minor > clientVersion.minor
  );
};
