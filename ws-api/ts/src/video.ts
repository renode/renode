// Copyright (c) 2026 Antmicro <www.antmicro.com>
//
// SPDX-License-Identifier: Apache-2.0

// Decodes the binary stream of a display endpoint (`/display/<port>`, see DisplayOpenedArgs).
// The wire format is documented in Antmicro.Renode.Analyzers.WebSocketVideoAnalyzer.

enum VideoMessageType {
  Config = 1,
  Frame = 2,
  Stats = 3,
}

export interface VideoConfig {
  width: number;
  height: number;
  tileSize: number;
  format: string;
}

export type VideoMessage =
  | { kind: 'config'; config: VideoConfig }
  | { kind: 'frame'; pixels: Uint8ClampedArray<ArrayBuffer> }
  | { kind: 'stats'; framesPerSecond: number };

export class DisplayDecoder {
  private config?: VideoConfig;
  private pixels = new Uint8ClampedArray(0);
  private decodeQueue: Promise<unknown> = Promise.resolve();

  // Frames only contain changed tiles applied over the current framebuffer, so
  // decoding is serialized to preserve message order despite asynchronous inflating
  public decode(data: ArrayBuffer): Promise<VideoMessage> {
    const result = this.decodeQueue.then(() => this.decodeInOrder(data));
    this.decodeQueue = result.catch(() => undefined);
    return result;
  }

  private async decodeInOrder(data: ArrayBuffer): Promise<VideoMessage> {
    const view = new DataView(data);
    const type = view.getUint8(0);

    if (type === VideoMessageType.Config) {
      const formatLength = view.getUint8(6);
      this.config = {
        width: view.getUint16(1, true),
        height: view.getUint16(3, true),
        tileSize: view.getUint8(5),
        format: new TextDecoder().decode(new Uint8Array(data, 7, formatLength)),
      };
      this.pixels = new Uint8ClampedArray(
        this.config.width * this.config.height * 4,
      );
      return { kind: 'config', config: this.config };
    }

    if (type === VideoMessageType.Stats) {
      return { kind: 'stats', framesPerSecond: view.getFloat32(1, true) };
    }

    if (type === VideoMessageType.Frame) {
      if (!this.config) {
        throw new Error('Video frame received before config');
      }
      this.applyTiles(this.config, await inflateRaw(data.slice(1)));
      return { kind: 'frame', pixels: this.pixels };
    }

    throw new Error(`Unknown video message type: ${type}`);
  }

  private applyTiles(
    { width, height, tileSize }: VideoConfig,
    payload: Uint8Array,
  ) {
    const tilesX = Math.ceil(width / tileSize);
    const tileCount = tilesX * Math.ceil(height / tileSize);
    let offset = Math.ceil(tileCount / 8);

    for (let tile = 0; tile < tileCount; tile++) {
      if ((payload[tile >> 3] & (1 << (tile & 7))) === 0) {
        continue;
      }
      const x = (tile % tilesX) * tileSize;
      const y = Math.floor(tile / tilesX) * tileSize;
      const rowBytes = Math.min(tileSize, width - x) * 4;
      const rows = Math.min(tileSize, height - y);
      for (let row = 0; row < rows; row++) {
        this.pixels.set(
          payload.subarray(offset, offset + rowBytes),
          ((y + row) * width + x) * 4,
        );
        offset += rowBytes;
      }
    }
  }
}

async function inflateRaw(data: ArrayBuffer): Promise<Uint8Array> {
  const stream = new Blob([data])
    .stream()
    .pipeThrough(new DecompressionStream('deflate-raw'));
  return new Uint8Array(await new Response(stream).arrayBuffer());
}
