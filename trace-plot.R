#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)

# First, install these R packages (in personal library, if needed)
suppressPackageStartupMessages({
  library(magrittr)
  library(data.table)
  library(lubridate)
  library(ggplot2)
  library(scales)
})

if (length(args) == 1) {
  traceFile <- args[1]
} else {
  traceFile <- "reports/trace.txt"
}
if (!file.exists(traceFile)) {
  stop(sprintf("File %s does not exist!", traceFile))
}

# Plot run times in violin plots
trace <- traceFile %>%
  lapply(fread) %>%
  rbindlist()

# Get all --everything flags to rename cols
allFlags <- readLines("input/vep-everything-flags.txt") %>%
  paste0(collapse=" ") %>%
  trimws()

nonRegFlags <- allFlags %>%
  gsub(pattern = "--regulatory", replacement = "") %>%
  gsub(pattern = "  ", replacement = " ")

documentedFlags <- "--sift b --polyphen b --ccds --hgvs --symbol --numbers --domains --regulatory --canonical --protein --biotype --uniprot --tsl --appris --gene_phenotype --af --af_1kg --af_esp --af_gnomad --max_af --pubmed --var_synonyms --variant_class --mane"
nonRegDocFlags  <- "--sift b --polyphen b --ccds --hgvs --symbol --numbers --domains --canonical --protein --biotype --uniprot --tsl --appris --gene_phenotype --af --af_1kg --af_esp --af_gnomad --max_af --pubmed --var_synonyms --variant_class --mane"

trace$class <- gsub("vep \\((.*) [0-9]*\\)", "\\1", trace$name)

nonRegFlags <- trace$class == nonRegFlags
documentedFlags <- trace$class == documentedFlags
nonRegDocFlags <- trace$class == nonRegDocFlags
trace$class[trace$class == allFlags] <- "All --everything flags explicitly stated"
trace$class[nonRegFlags]       <- "All --eveything flags minus --regulatory explicitly stated"
trace$class[documentedFlags]   <- "All (documented) --everything flags explicitly stated"
trace$class[nonRegDocFlags]    <- "All (documented) --everything flags explicitly stated minus --regulatory"
trace$class[trace$class == ""] <- "baseline*"

#trace <- trace[allFlags | nonRegFlags | documentedFlags | nonRegDocFlags | trace$class == "--everything", ]

trace$class <- factor(trace$class)

# Convert "realtime" column from string to time
trace$realtime <- parse_date_time(trace$realtime, c("HMS", "HM"))
trace$sep      <- trace$realtime < parse_date_time(3, "H")

# Plot VEP runtimes -----------------------------------------------------------

baseline <- paste(
  "*baseline: perl vep --i NA12878.vcf.gz --offline --cache",
  "--dir_cache /nfs/production/flicek/ensembl/variation/data/VEP\n--assembly",
  "GRCh38 --fasta Homo_sapiens.GRCh38.dna.toplevel.fa.gz")

trace$class <- reorder(trace$class, trace$realtime, median)

# Calculate median
df     <- data.frame(class=trace$class)
df$med <- sapply(split(trace$realtime, trace$class), median)

n_fun <- function(x){
  parse  <- function(i) make_datetime(sec=seconds(i))
  pretty <- function(k) format(k, "%k:%M")
  med    <- parse(median(x))
  return(data.frame(y=med, yintercept=med,
                    label=sprintf("%s\n\n\n", pretty(med))))
}

ggplot(trace, aes(realtime, class, fill=class, color=class)) +
  geom_violin(alpha=0.5) +
  geom_jitter(alpha=0.5) +
  stat_summary(fun.data=n_fun, geom="text", hjust=1.1) +
  stat_summary(fun.data=n_fun, geom="vline", linetype="dashed") +
  xlab("Time (hours)") +
  ylab("") +
  scale_y_discrete(labels = wrap_format(20)) +
  scale_x_datetime(breaks=make_datetime(0, min=seq(60, 60 * 10, 30)),
                   date_labels = "%H:%M") +
  labs(title="VEP runs",
       subtitle="Median values presented over 10 runs", caption=baseline) +
  theme_bw() +
  theme(legend.position = 'none')

traceFile <- tools::file_path_sans_ext(traceFile)
outFile   <- paste0(traceFile, "-runtimes.png")

# Ask to overwrite file, if it exists
owMsg <- sprintf("File %s alreadys exists; aborting.", outFile)
if (file.exists(outFile)) stop(owMsg) 
ggsave(outFile, width=8, height=5)
cat(paste("Plot successfuly saved to:", outFile), fill=TRUE)

# Plot VEP runtimes per node --------------------------------------------------

## Highlight nodes where many jobs run
#discardNodes <- names(table(trace$node)[table(trace$node) < 7])
#trace$highlightedNodes <- trace$node
#trace$highlightedNodes[trace$node %in% discardNodes] <- "Other nodes (<7 jobs each)"

#ggplot(trace, aes(realtime, reorder(highlightedNodes, realtime, FUN=mean),
#                  color=class)) +
#  geom_boxplot(aes(color=NULL), fill='gray', alpha=0.2) +
#  geom_jitter(alpha=0.5) +
#  xlab("VEP runtime") +
#  ylab("") +
#  scale_y_discrete(labels = wrap_format(15)) +
#  scale_x_datetime(breaks=parse_date_time(1:15, "H"), date_labels = "%H:%M") +
#  labs(title="VEP run per node", caption=baseline) +
#  theme_bw() +
#  theme(legend.position = "bottom") +
#  guides(color=guide_legend(nrow=2,byrow=TRUE))
#ggsave("reports/vep-runtimes-per-node.png")
