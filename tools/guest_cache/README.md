# Renode Guest Cache Modelling Analyzer

## Generating traces from Renode:

Add the following lines to the `resc` file:

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
$ ./renode_cache_interface.py trace.log presets fu740.u74
l1i,u74 configuration:
Cache size:          32768 bytes
Block size:          64 bytes
Number of lines:     512
Number of sets:      128 (4 lines per set)
Replacement policy:  RAND

l1d,u74 configuration:
Cache size:          32768 bytes
Block size:          64 bytes
Number of lines:     512
Number of sets:      64 (8 lines per set)
Replacement policy:  RAND

Instructions read: 174620452
Total memory operations: 68952483 (read: 50861775, write 18090708)
Total I/O operations: 1875 (read: 181, write 1694)

l1i,u74 results:
Misses: 168
Hits: 174620284
Invalidations: 3
Hit ratio: 100.0%

l1d,u74
Misses: 17320212
Hits: 51632271
Invalidations: 17319700
Hit ratio: 74.88%
```

Full documentation on guest CPU cache modeling is available in the [Renode documentation](https://renode.readthedocs.io/en/latest/advanced/execution-tracing.html#guest-cpu-cache-modelling).
