# ENSVAR-4550: benchmark impact of --everything arguments

This project benchmarks VEP when using the [`--everything`][everything] flag,
a shortcut that enables multiple VEP flags. All the flags enabled when setting
`--everything` were saved to [`input/vep-everything-flags.txt`][flagsFile].

[everything]: https://www.ensembl.org/info/docs/tools/vep/script/vep_options.html#opt_everything
[flagsFile]: input/vep-everything-flags.txt

The script will run the following test cases multiple times:
1. VEP in offline mode, using cache and fasta (baseline)

```bash
vcf="NA12878.vcf.gz" # obtained according to https://github.com/Illumina/PlatinumGenomes
fasta="Homo_sapiens.GRCh38.dna.toplevel.fa.gz"
perl vep --i $vcf --offline --cache --dir_cache $cache --assembly GRCh38 --fasta $fasta
```

2. Baseline with each of the flags enabled individually to test times of other
flags
3. Baseline with all allele frequency (AF) flags at the same time:
`--af --af_1kg --af_esp --af_gnomad --max_af`
4. Baseline with `--everything`
5. Baseline with all flags set by `--everything` (should run for the same time
as previous condition)
6. Previous condition except for each of the following flags were not used:
`--regulatory`, `--hgvs`, `--pubmed`, `--af`, `--af_1kg` and all AF flags

Note: if running in a cluster, each run should reserve a single node to ensure
stable runtimes. This can be done by asking all cores of a single node, for
instance.

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

Make sure to install the following R packages in either your system or your
personal library via R:

```R
install.packages(c("magrittr", "data.table", "lubridate", "ggplot2", "scales"))
```

To plot runtimes, run the R script `trace-plot.R` with a trace report filepath
as input:

```bash
./trace-plot.R reports/trace.txt
```

The resulting plot will be saved in the same folder of the input file and its
filename will be the name of the input file followed by `-runtimes`. The script
aborts if the output file already exists.
