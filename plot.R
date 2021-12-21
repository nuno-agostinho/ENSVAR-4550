#!/usr/bin/env Rscript

# Plot run times in violin plots
library(magrittr)
library(data.table)
trace <- "reports/trace-100runs-nodes.txt" %>%
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
nonRegDocFlags <-  "--sift b --polyphen b --ccds --hgvs --symbol --numbers --domains --canonical --protein --biotype --uniprot --tsl --appris --gene_phenotype --af --af_1kg --af_esp --af_gnomad --max_af --pubmed --var_synonyms --variant_class --mane"

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

# Convert "duration" column to time
library(lubridate)
trace$duration <- parse_date_time(trace$duration, c("HMS", "HM"))

# Highlight nodes where many jobs run
discardNodes <- names(table(trace$node)[table(trace$node) < 7])
trace$highlightedNodes <- trace$node
trace$highlightedNodes[trace$node %in% discardNodes] <- "Other nodes (<7 jobs each)"

# Plot run times
library(ggplot2)
library(scales)

baseline <- paste(
  "*baseline: perl vep --i NA12878.vcf.gz --offline --cache",
  "--dir_cache /nfs/production/flicek/ensembl/variation/data/VEP\n--assembly",
  "GRCh38 --fasta Homo_sapiens.GRCh38.dna.toplevel.fa.gz")

ggplot(trace, aes(duration, class, fill=class, color=class)) +
  geom_violin(alpha=0.5) +
  geom_jitter(alpha=0.5) +
  xlab("VEP runtime") +
  ylab("") +
  scale_y_discrete(labels = wrap_format(20)) +
  scale_x_datetime(breaks=parse_date_time(1:15, "H"), date_labels = "%H:%M") +
  labs(title="VEP run", caption=baseline) +
  theme_bw() +
  theme(legend.position = 'none')

ggplot(trace, aes(duration, reorder(highlightedNodes, duration, FUN=mean),
                  color=class)) +
  geom_boxplot(aes(color=NULL), fill='gray', alpha=0.2) +
  geom_jitter(alpha=0.5) +
  xlab("VEP runtime") +
  ylab("") +
  scale_y_discrete(labels = wrap_format(15)) +
  scale_x_datetime(breaks=parse_date_time(1:15, "H"), date_labels = "%H:%M") +
  labs(title="VEP run per node", caption=baseline) +
  theme_bw() +
  theme(legend.position = "bottom") +
  guides(color=guide_legend(nrow=2,byrow=TRUE))

