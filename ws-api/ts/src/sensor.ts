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
  Illuminance = 'illuminance',
}

export enum SensorValueRepresentation {
  Raw = 'raw',
  Percent = 'percent',
  Discrete = 'discrete',
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
    [SensorType.Illuminance]: IlluminanceValue,
  };

  const ctor = mapping[type];
  return ctor.fromValueChecked.bind(ctor);
}

export function GetSensorValue(
  measurand: SensorType,
  value: unknown,
  pretty: boolean = false,
): SensorValue {
  return sensorConstructorForType(measurand)(value, pretty);
}

export function GetSensorSourceValue(
  measurand: SensorType,
  type: 'raw' | 'percent' | 'discrete',
  value: unknown,
  pretty: boolean = false,
): SensorValue {
  switch (type) {
    case 'raw':
      return sensorConstructorForType(measurand)(value, pretty);
    case 'percent':
      return PercentageScalar.fromValueChecked(value, pretty);
    case 'discrete':
      return DiscreteValue.fromValueChecked(value, pretty);
  }
}

export class Sensor extends Peripheral {
  public constructor(
    machine: string,
    name: string,
    public readonly measurands: Partial<
      Record<SensorType, SensorValueRepresentation[]>
    >,
  ) {
    super(machine, name);
  }

  get types(): SensorType[] {
    return Object.keys(this.measurands) as SensorType[];
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

const DiscreteSampleValue = z.string();
export type DiscreteSampleValue = z.infer<typeof DiscreteSampleValue>;

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
  ): AngularRateValue {
    if (pretty) sample = vec3Map(sample, val => Math.round(val * 1e5));
    return new this(sample, 'rad/s');
  }
}

export class VoltageValue extends ScalarSensorValue {
  override get value() {
    return this.sample / 1e6;
  }

  public static fromValue(sample: number, pretty: boolean): VoltageValue {
    if (pretty) sample = Math.round(sample * 1e6);
    return new this(sample, 'V');
  }
}

export class ECGValue extends ScalarSensorValue {
  public static fromValue(sample: number, pretty: boolean): ECGValue {
    if (pretty) sample = Math.round(sample);
    return new this(sample, 'nV');
  }
}

export class HumidityValue extends ScalarSensorValue {
  override get value() {
    return this.sample / 1e3;
  }

  public static fromValue(sample: number, pretty: boolean): HumidityValue {
    if (pretty) sample = Math.round(sample * 1e3);
    return new this(sample, '%RH');
  }
}

export class PressureValue extends ScalarSensorValue {
  get value() {
    return this.sample / 1e3;
  }

  public static fromValue(sample: number, pretty: boolean): PressureValue {
    if (pretty) sample = Math.round(sample * 1e3);
    return new this(sample, 'Pa');
  }
}

export class MagneticFluxDensityValue extends Vec3SensorValue {
  public static fromValue(
    sample: Vec3SampleValue,
    pretty: boolean,
  ): MagneticFluxDensityValue {
    if (pretty) sample = vec3Map(sample, val => Math.round(val));
    return new this(sample, 'nT');
  }
}

export class IlluminanceValue extends ScalarSensorValue {
  get value() {
    return this.sample / 1e3;
  }

  public static fromValue(sample: number, pretty: boolean): IlluminanceValue {
    if (pretty) sample = Math.round(sample * 1e3);
    return new this(sample, 'lx');
  }
}

export class PercentageScalar extends ScalarSensorValue {
  get value() {
    return this.sample / 1e3;
  }

  public static fromValue(sample: number, pretty: boolean): PercentageScalar {
    if (pretty) sample = Math.round(sample * 1e3);
    return new this(sample, '%');
  }
}

export class PercentageVector extends Vec3SensorValue {
  override get value() {
    return vec3Map(this.sample, v => v / 1e3);
  }

  public static fromValue(
    sample: Vec3SampleValue,
    pretty: boolean,
  ): PercentageVector {
    if (pretty) sample = vec3Map(sample, val => Math.round(val * 1e3));
    return new this(sample, '%');
  }
}

export class DiscreteValue extends SensorValue<DiscreteSampleValue> {
  protected constructor(
    readonly sample: DiscreteSampleValue,
    readonly unit: string,
  ) {
    super();
  }

  override get value() {
    return this.sample;
  }

  public static fromValueChecked(
    sample: unknown,
    pretty: boolean,
  ): DiscreteValue {
    const sampleChecked = DiscreteSampleValue.parse(sample);
    return this.fromValue(sampleChecked, pretty);
  }

  public static fromValue(sample: string, _pretty: boolean): DiscreteValue {
    return new this(sample, '');
  }
}
