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

Install [Nextflow](https://nextflow.io) and run:

```
bsub nextflow run main.nf
```

To change the number of runs of each test:

```
bsub nextflow run main.nf --repeat 3
```

To override the tested flags (notice that there needs to be a space for
Nextflow to correctly interpret the parameter as a string and not as an
argument for itself):

```
bsub nextflow run main.nf --flags "--regulatory "
```

Note: `nextflow.config` may have been configured to run a max number of
parallel tasks to run in the cluster using the option `executor.queueSize`.

## Output

Standard output and error logs (STDOUT and STDERR) are saved in folder `logs`.
VEP output files are discarded given that we are only interested in
benchmarking time.

As defined in `nextflow.config`, multiple reports are saved in folder
`reports`. The most important is the trace report (`trace*.txt`), a table that
summarises the run info, including runtimes in column `realtime` (column
`duration` shows runtime plus queue waiting time).
[Learn more...](https://www.nextflow.io/docs/latest/tracing.html#trace-report)

### Plot output

To plot runtimes, run the R script `trace-plot.R` with a trace report filepath
as input:

```bash
./trace-plot.R reports/trace.txt
```

The resulting plot will be saved in the same folder of the input file and its
filename will be the name of the input file followed by `-runtimes`. The script
aborts if the output file already exists.
