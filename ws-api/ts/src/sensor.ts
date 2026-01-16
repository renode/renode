// Copyright (c) 2026 Antmicro <www.antmicro.com>
//
// SPDX-License-Identifier: Apache-2.0

import { z } from 'zod';
import { Peripheral } from './peripheral';

export enum SensorType {
  Temperature = 'temperature',
  Acceleration = 'acceleration',
  AngularRate = 'angular-rate',
  Voltage = 'voltage',
  ECG = 'ecg',
  Humidity = 'humidity',
  Pressure = 'pressure',
  MagneticFluxDensity = 'magnetic-flux-density',
}

export function SensorTypeFromString(value: string): SensorType | undefined {
  return (Object.values(SensorType) as string[]).includes(value)
    ? (value as SensorType)
    : undefined;
}

function sensorConstructorForType(
  type: SensorType,
): (sample: unknown, pretty: boolean) => SensorValue {
  const mapping = {
    [SensorType.Temperature]: TemperatureValue,
    [SensorType.Acceleration]: AccelerationValue,
    [SensorType.AngularRate]: AngularRateValue,
    [SensorType.Voltage]: VoltageValue,
    [SensorType.ECG]: ECGValue,
    [SensorType.Humidity]: HumidityValue,
    [SensorType.Pressure]: PressureValue,
    [SensorType.MagneticFluxDensity]: MagneticFluxDensityValue,
  };

  const ctor = mapping[type];
  return ctor.fromValueChecked.bind(ctor);
}

export function GetSensorValue(
  type: SensorType,
  value: unknown,
  pretty: boolean = false,
): SensorValue {
  return sensorConstructorForType(type)(value, pretty);
}

export class Sensor extends Peripheral {
  public constructor(
    machine: string,
    name: string,
    public readonly types: SensorType[],
  ) {
    super(machine, name);
  }
}

export abstract class SensorValue<SampleType = unknown> {
  public abstract readonly sample: SampleType;
  public abstract readonly unit: string;
  public abstract get value(): SampleType;

  public static fromValueChecked(
    _sample: unknown,
    _pretty: boolean,
  ): SensorValue {
    throw new Error('Cannot construct abstract class SensorValue');
  }
}

const ScalarSampleValue = z.number();
export type ScalarSampleValue = z.infer<typeof ScalarSampleValue>;

const Vec3SampleValue = z.object({
  x: z.number(),
  y: z.number(),
  z: z.number(),
});
export type Vec3SampleValue = z.infer<typeof Vec3SampleValue>;

function vec3Map(
  v: Vec3SampleValue,
  fun: (value: number) => number,
): Vec3SampleValue {
  return {
    x: fun(v.x),
    y: fun(v.y),
    z: fun(v.z),
  };
}

class ScalarSensorValue extends SensorValue<ScalarSampleValue> {
  protected constructor(
    readonly sample: ScalarSampleValue,
    readonly unit: string,
  ) {
    super();
  }

  override get value() {
    return this.sample;
  }

  public static fromValue(
    _sample: ScalarSampleValue,
    _pretty: boolean,
  ): ScalarSensorValue {
    throw new Error('Cannot construct abstract class ScalarSensorValue');
  }

  public static fromValueChecked(sample: unknown, pretty: boolean) {
    const sampleChecked = ScalarSampleValue.parse(sample);
    return this.fromValue(sampleChecked, pretty);
  }
}

class Vec3SensorValue extends SensorValue<Vec3SampleValue> {
  protected constructor(
    readonly sample: Vec3SampleValue,
    readonly unit: string,
  ) {
    super();
  }

  override get value() {
    return this.sample;
  }

  public static fromValue(
    _sample: Vec3SampleValue,
    _pretty: boolean,
  ): Vec3SensorValue {
    throw new Error('Cannot construct abstract class ScalarSensorValue');
  }

  public static fromValueChecked(sample: unknown, pretty: boolean) {
    const sampleChecked = Vec3SampleValue.parse(sample);
    return this.fromValue(sampleChecked, pretty);
  }
}

export class TemperatureValue extends ScalarSensorValue {
  override get value() {
    return this.sample / 1e3;
  }

  public static fromValue(sample: number, pretty: boolean): TemperatureValue {
    if (pretty) sample = Math.round(sample * 1e3);
    return new this(sample, '°C');
  }
}

export class AccelerationValue extends Vec3SensorValue {
  override get value() {
    return vec3Map(this.sample, v => v / 1e6);
  }

  public static fromValue(
    sample: Vec3SampleValue,
    pretty: boolean,
  ): AccelerationValue {
    if (pretty) sample = vec3Map(sample, val => Math.round(val * 1e6));
    return new this(sample, 'g');
  }
}

export class AngularRateValue extends Vec3SensorValue {
  override get value() {
    return vec3Map(this.sample, v => v / 1e5);
  }

  public static fromValue(
    sample: Vec3SampleValue,
    pretty: boolean,
  ): AccelerationValue {
    if (pretty) sample = vec3Map(sample, val => Math.round(val * 1e5));
    return new this(sample, 'rad/s');
  }
}

export class VoltageValue extends ScalarSensorValue {
  override get value() {
    return this.sample / 1e6;
  }

  public static fromValue(sample: number, pretty: boolean): TemperatureValue {
    if (pretty) sample = Math.round(sample * 1e6);
    return new this(sample, 'V');
  }
}

export class ECGValue extends ScalarSensorValue {
  public static fromValue(sample: number, pretty: boolean): TemperatureValue {
    if (pretty) sample = Math.round(sample);
    return new this(sample, 'nV');
  }
}

export class HumidityValue extends ScalarSensorValue {
  override get value() {
    return this.sample / 1e3;
  }

  public static fromValue(sample: number, pretty: boolean): TemperatureValue {
    if (pretty) sample = Math.round(sample * 1e3);
    return new this(sample, '%RH');
  }
}

export class PressureValue extends ScalarSensorValue {
  get value() {
    return this.sample / 1e3;
  }

  public static fromValue(sample: number, pretty: boolean): TemperatureValue {
    if (pretty) sample = Math.round(sample * 1e3);
    return new this(sample, 'Pa');
  }
}

export class MagneticFluxDensityValue extends Vec3SensorValue {
  public static fromValue(
    sample: Vec3SampleValue,
    pretty: boolean,
  ): AccelerationValue {
    if (pretty) sample = vec3Map(sample, val => Math.round(val));
    return new this(sample, 'nT');
  }
}
