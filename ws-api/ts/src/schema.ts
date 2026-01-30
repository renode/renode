// Copyright (c) 2026 Antmicro <www.antmicro.com>
//
// SPDX-License-Identifier: Apache-2.0

import { z, ZodRawShape } from 'zod';
import * as semver from 'semver';

export const BaseResponse = z.object({
  status: z.string(),
  version: z.string().refine(s => semver.valid(s) != null),
});
export const OkResponse = BaseResponse.extend({
  id: z.number(),
  status: z.literal('success'),
  data: z.any(),
});
export type OkResponse = z.infer<typeof OkResponse>;
export const ErrorResponse = BaseResponse.extend({
  status: z.literal('failure'),
  error: z
    .string()
    .nullish()
    .transform(err => err ?? 'Unknown error'),
});
export type ErrorResponse = z.infer<typeof ErrorResponse>;
export const Response = OkResponse.or(ErrorResponse);
export type Response = z.infer<typeof Response>;

function resp<T extends ZodRawShape>(obj: T) {
  return OkResponse.extend(obj).or(ErrorResponse);
}

export const SpawnResponse = resp({
  data: z.object({}),
});
export type SpawnResponse = z.infer<typeof SpawnResponse>;

export const KillResponse = resp({
  data: z.object({}),
});
export type KillResponse = z.infer<typeof KillResponse>;

export const ExecMonitorResponse = resp({});
export type ExecMonitorResponse = z.infer<typeof ExecMonitorResponse>;

export const GetUartsResponse = resp({
  data: z.string().array(),
});
export const GetButtonsResponse = resp({
  data: z.string().array(),
});
export const GetLedsResponse = resp({
  data: z.string().array(),
});
export type GetUartsResponse = z.infer<typeof GetUartsResponse>;

export const GetMachinesResponse = resp({
  data: z.string().array(),
});
export type GetMachinesResponse = z.infer<typeof GetMachinesResponse>;

export const GetSensorsResponse = resp({
  data: z
    .object({
      name: z.string(),
      types: z.string().array(),
    })
    .array(),
});
export type GetSensorsResponse = z.infer<typeof GetSensorsResponse>;

export const GetSensorResponse = resp({
  data: z.unknown(),
});
export type GetSensorResponse = z.infer<typeof GetSensorResponse>;

export const EmptyExecResponse = resp({
  data: z.literal('ok'),
});
export type EmptyExecResponse = z.infer<typeof EmptyExecResponse>;

export const FsListResponse = resp({
  data: z
    .object({
      name: z.string(),
      isfile: z.boolean(),
      islink: z.boolean(),
    })
    .array(),
});
export type FsListResponse = z.infer<typeof FsListResponse>;

export const FsStatResponse = resp({
  data: z.object({
    size: z.number(),
    isfile: z.boolean(),
    ctime: z.number(),
    mtime: z.number(),
  }),
});
export type FsStatResponse = z.infer<typeof FsStatResponse>;

export const FsDwnlResponse = resp({
  data: z.string().base64(),
});
export type FsDwnlResponse = z.infer<typeof FsDwnlResponse>;

export const FsUpldResponse = resp({
  data: z.object({
    path: z.string(),
  }),
});
export type FsUpldResponse = z.infer<typeof FsUpldResponse>;

export const FsRemoveResponse = resp({
  data: z.object({
    path: z.string(),
  }),
});
export type FsRemoveResponse = z.infer<typeof FsRemoveResponse>;

export const FsMkdirResponse = resp({
  data: z.object({}),
});
export type FsMkdirResponse = z.infer<typeof FsMkdirResponse>;

export const FsZipResponse = resp({
  data: z.object({
    path: z.string(),
  }),
});
export type FsZipResponse = z.infer<typeof FsZipResponse>;

export const FsFetchResponse = resp({
  data: z.object({
    path: z.string(),
  }),
});
export type FsFetchResponse = z.infer<typeof FsFetchResponse>;

export const FsMoveResponse = resp({
  data: z.object({
    from: z.string(),
    to: z.string(),
  }),
});
export type FsMoveResponse = z.infer<typeof FsMoveResponse>;

export const FsCopyResponse = resp({
  data: z.object({
    from: z.string(),
    to: z.string(),
  }),
});
export type FsCopyResponse = z.infer<typeof FsCopyResponse>;

export const ReplaceAnalyzersResponse = resp({
  data: z.object({}),
});
export type ReplaceAnalyzersResponse = z.infer<typeof ReplaceAnalyzersResponse>;

export const FilterEventsResponse = resp({
  data: z.object({}),
});
export type FilterEventsResponse = z.infer<typeof FilterEventsResponse>;
