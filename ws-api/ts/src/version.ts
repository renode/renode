// Copyright (c) 2026 Antmicro <www.antmicro.com>
//
// SPDX-License-Identifier: Apache-2.0

import semver from 'semver';

export const version: string = '1.5.0';
export const clientVersion: semver.SemVer = semver.parse(version)!;

export const isOutdatedClientVersion = (val: string): boolean => {
  const apiVersion = semver.parse(val);
  return (
    apiVersion?.major != clientVersion.major ||
    apiVersion.minor > clientVersion.minor
  );
};
