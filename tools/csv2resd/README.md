# csv-to-resd

This directory contains the CSV2RESD tool, which allows converting CSV files to RESD (**RE**node **S**ensor **D**ata) file format.

## Usage

### Syntax
`./csv2resd.py [GROUP1] [GROUP2] [GROUP2] ...`

`GROUP ::= --input <csv-file> [--offset <offset>] [--count <count>] [--map <type>:<field(s)>:<target(s)>*:<channel>*] --start-time <start-time> --frequency <frequency> --timestamp <timestamp>`

Syntax allows for multiple specification of group, where `--input` is a delimiter between groups.
For each `--input`, multiple mappings (`--map`) can be specified. The `*` in `--map` signs, that given property is optional:
`--map <type>:<field(s)>`, `--map <type>:<field(s)>:<target(s)>`, `--map <type>:<field(s)>:<target(s)>:<channel>` and `--map <type>:<field>::<channel>` are all correct mappings.

For more information, refer to `--help`.

### Example

`./csv2resd.py --input first.csv --map temperature:temp1::0 --map temperature:temp2::1 --start-time 0 --frequency 1 --input second.csv --map temperature:temp::2 --start-time 0 --frequency 1 output.resd`

**first.csv**
```
temp1,temp2
32502,32003
32638,31603
32633,31565
33060,31975
31617,32368
32912,31284
31813,31915
31999,31961
31811,32049
31427,32409
```

**second.csv**
```
temp
32139
32253
32402
32004
32037
32698
31687
32658
32452
32300
```

Above example extracts `temp1` and `temp2` columns from `first.csv` and `temp` from `second.csv`, and then maps it to temperature channels `0`, `1` and `2` in RESD respectively.
