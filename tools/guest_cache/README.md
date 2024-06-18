# Renode Guest Cache Modelling Script

## Generating traces from Renode:

* Add the following lines to the `resc` file:
    ```text
    cpu MaximumBlockSize 1
    cpu CreateExecutionTracing "tracer" $ORIGIN/trace.log PCAndOpcode
    tracer TrackMemoryAccesses
    ```

## Usage:

* Using build-in presets
  ```text
    ./renode_cache_interface.py trace.log presets 'fu740.u74'
  ```

* Custom cache configuration
  ```text
  ./renode_cache_interface.py trace.log config            \
                            --memory_width 64             \
                            --l1i_cache_width 15          \
                            --l1i_block_width 6           \
                            --l1i_lines_per_set 4         \
                            --l1i_replacement_policy LRU  \
                            --l1d_cache_width 15          \
                            --l1d_block_width 6           \
                            --l1d_lines_per_set 8         \
                            --l1d_replacement_policy LRU  \
  ```

An example output of the analysis:

```text
$ ./renode_cache_interface.py trace.log presets fe310.e31
addressing:
tag: 19 bits
set: 8 bits
block: 5 bits

cache configuration
block: 5 bits
msize:  4294967296 bytes
csize:  16384 bytes
bsize:  32 bytes
clines: 512
csets:  256 (2 lines per set)

100%|██████████████████████████████████████████████████████████████████████████████████████████████████████████████| 641624/641624 [00:01<00:00, 509195.05it/s]

insn_read: 514636
mem_total: 0 (read: 0, write 0)
io_total: 0 (read: 0, write 0)

l1i,e31
m: 224
h: 514412
i: 0
hmr: 99.96%
```
