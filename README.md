# ENSVAR-4550: benchmark impact of --regulatory on VEP annotation speed

This project benchmarks VEP when using the `--everything` flag, a shortcut that
enables multiple VEP flags:
https://www.ensembl.org/info/docs/tools/vep/script/vep_options.html#opt_everything

All the flags enabled when setting `--everything` were saved to
`vep-everything-flags.txt`.

The script will run the following test cases multiple times:
1. VEP in offline mode, using cache and fasta (baseline)
2. Condition 1 with `--everything`
3. Condition 1 with all flags set by `--everything` (should run for the same
time as previous condition)
4. Condition 3 except for `--regulatory`
5. Condition 1 with each of the flags enabled individually to test times of
other flags

## How to run the script

Install [Nextflow](nextflow.io) and run:

```
nextflow run main.nf
```

Use the argument `--repeat` to change the number of runs of each test:

```
nextflow run main.nf --repeat 3
```

## Output

Standard output and error logs (STDOUT and STDERR) are saved in folder `logs`.
VEP output files are discarded given that we are only interested in
benchmarking time.
