#!/usr/bin/env python

from grammar import resd_header, data_block, data_block_sample_frequency, data_block_sample_arbitrary, data_block_header, data_block_subheader, data_block_metadata_item, BLOCK_TYPE, SAMPLE_TYPE

__VERSION__ = 1


class RESD:
    def __init__(self, file_path):
        self.file_handle = open(file_path, 'wb')
        self.blocks = {}
        self._write_header()

    def __del__(self):
        self.flush()
        self.file_handle.close()

    def new_block(self, sample_type, block_type, channel_id=0):
        previous_block = self.get_block(sample_type, channel_id)
        if previous_block is not None:
            self.flush(sample_type, channel_id)

        block = ({
            BLOCK_TYPE.CONSTANT_FREQUENCY: RESDBlockConstantFrequency,
            BLOCK_TYPE.ARBITRARY_TIMESTAMP: RESDBlockArbitraryTimestamp
        })[block_type](sample_type, block_type, channel_id)

        self.blocks[(sample_type, channel_id)] = block
        return block

    def get_block(self, sample_type, channel_id=0):
        return self.blocks.get((sample_type, channel_id), None)

    def get_block_or_create(self, sample_type, block_type, channel_id=0):
        block = self.get_block(sample_type, channel_id)
        return block if block else self.new_block(sample_type, block_type, channel_id)

    def flush(self, sample_type=None, channel_id=None):
        for key in list(self.blocks.keys()):
            block_sample_type, block_channel_id = key

            if sample_type and block_sample_type != sample_type:
                continue
            if channel_id and block_channel_id != channel_id:
                continue

            self.blocks[key].flush(self.file_handle)
            del self.blocks[key]

    def _write_header(self):
        resd_header.build_stream({
            'version': __VERSION__,
        }, self.file_handle)


class RESDBlock:
    def __init__(self, sample_type, block_type, channel_id):
        self.sample_type = sample_type
        self.block_type = block_type
        self.channel_id = channel_id
        self.block_metadata = RESDBlockMetadata()
        self.samples = []

    @property
    def metadata(self):
        return self.block_metadata

    def flush(self, file):
        metadata = self.metadata.build()
        data_size = (
            data_block_subheader.sizeof(header={'block_type': self.block_type}) +
            metadata['size'] + 8 +
            self._samples_sizeof()
        )

        header = self._header(data_size)
        subheader = self._subheader()
        data_block.build_stream({
            'header': header,
            'subheader': subheader,
            'metadata': metadata,
            'samples': self.samples,
        }, file)

    def _header(self, data_size):
        return {
            'block_type': self.block_type,
            'sample_type': self.sample_type,
            'channel_id': self.channel_id,
            'data_size': data_size,
        }

    def _subheader(self):
        return None

    def _samples_sizeof(self):
        pass

    @classmethod
    def _wrap_sample(cls, sample):
        if isinstance(sample, bytes):
            sample = {
                'size': len(sample),
                'data': sample,
            }
        return sample


class RESDBlockConstantFrequency(RESDBlock):
    __period = int(1e9)
    __start_time = 0

    @property
    def period(self):
        return self.__period

    @period.setter
    def period(self, value):
        self.__period = value

    @property
    def frequency(self):
        return 1e9 / self.__period

    @frequency.setter
    def frequency(self, value):
        self.__period = int(1e9 / value)

    @property
    def start_time(self):
        return self.__start_time

    @start_time.setter
    def start_time(self, value):
        self.__start_time = value

    def add_sample(self, sample):
        self.samples.append({'sample': RESDBlock._wrap_sample(sample)})

    def _subheader(self):
        return {
            'start_time': self.__start_time,
            'period': self.__period
        }

    def _samples_sizeof(self):
        return sum(len(data_block_sample_frequency(self.sample_type).build(sample)) for sample in self.samples)


class RESDBlockArbitraryTimestamp(RESDBlock):
    __start_time = 0

    @property
    def start_time(self):
        return self.__start_time

    @start_time.setter
    def start_time(self, value):
        self.__start_time = value

    def add_sample(self, sample, timestamp):
        self.samples.append({'sample': RESDBlock._wrap_sample(sample), 'timestamp': timestamp})

    def _subheader(self):
        return {
            'start_time': self.__start_time,
        }

    def _samples_sizeof(self):
        return sum(len(data_block_sample_arbitrary(self.sample_type).build(sample)) for sample in self.samples)


class RESDBlockMetadata:
    def __init__(self):
        self.metadata = []
        self.keys = set()

    def __getattr__(self, name):
        prefix = 'insert_'
        if name[:len(prefix)] != prefix:
            return None

        method = name[len(prefix):]
        type_idx = ({
            'int8':   0x01,
            'uint8':  0x02,
            'int16':  0x03,
            'uint16': 0x04,
            'int32':  0x05,
            'uint32': 0x06,
            'int64':  0x07,
            'uint64': 0x08,
            'float':  0x09,
            'double': 0x0A,
            'text':   0x0B,
            'blob':   0x0C,
        }).get(method, None)

        if method is None:
            return None

        return lambda key, value: self._insert(type_idx, key, value)

    def build(self):
        return {'items': self.metadata, 'size': self._sizeof()}

    def remove(self, key):
        if key not in self.keys:
            return
        self.keys.remove(key)
        index = next(i for i, value in enumerate(self.metadata) if value['key'] == key)
        self.metadata.pop(index)

    def _sizeof(self):
        return sum(len(data_block_metadata_item.build(item)) for item in self.metadata)

    def _insert(self, type_idx, key, value):
        self.remove(key)
        self.keys.add(key)
        self.metadata.append({
            'type': type_idx,
            'key': key,
            'value': value
        })
