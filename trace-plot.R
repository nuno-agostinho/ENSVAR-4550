#!/usr/bin/env Rscript
# Create plot of VEP runtimes based on Nextflow's trace.txt file
# Use like so: ./trace-plot.R [trace.txt]
# A plot is generated in the same directory as trace.txt
args = commandArgs(trailingOnly=TRUE)

# First, install these R packages (in personal library, if needed)
suppressPackageStartupMessages({
  library(magrittr)
  library(data.table)
  library(lubridate)
  library(ggplot2)
  library(scales)
})

# Parse command-line arguments -------------------------------------------------
if (length(args) == 1) {
  traceFile <- args[1]
} else {
  traceFile <- "reports/trace.txt"
}
if (!file.exists(traceFile)) {
  stop(sprintf("File %s does not exist!", traceFile))
}

# Plot run times in violin plots -----------------------------------------------
trace <- fread(traceFile)

# Get all --everything flags to rename cols
allFlags <- readLines("input/vep-everything-flags.txt") %>%
  Filter(f=nchar) # remove empty lines

trace$class <- gsub("vep \\((.*) [0-9]*\\)", "\\1", trace$name)
trace$sep <- gsub(" --", ";;;--", trace$class) %>%
  sapply(strsplit, ";;;") # correctly split each argument

# Rename classes
trace$class[trace$class == ""] <- "baseline*"

len <- sapply(trace$sep, length)

missingFlags <- lapply(trace$sep, setdiff, x=allFlags) %>%
  sapply(paste, collapse=" ")
missingMsg <- "All --everything flags minus %s"
condition  <- len > 10
trace$class[condition] <- sprintf(missingMsg, missingFlags)[condition]

everything <- sapply(trace$sep, function(i) all(allFlags %in% i))
trace$class[everything] <- "All --everything flags explicitly stated"

trace$class <- gsub("--af .*", "All AF flags", trace$class)
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
trace$everything <- ifelse(grepl("--everything", trace$class),
                           "Based on --everything",
                           "Based on baseline")

# Calculate median
n_fun <- function(x){
  todate <- function(i) make_datetime(sec=seconds(i + 600))
  med    <- todate(median(x))
  maxi   <- todate(max(x))
  
  pretty <- function(k) format(k, "%k:%M")
  return(data.frame(y=maxi, yintercept=med,
                    label=sprintf("%s", pretty(med))))
}

tab <- table(trace$class)
subtitle <- sprintf("Median values presented over %s%s runs", min(tab),
                    ifelse(max(tab) > min(tab),
                           paste0(" up to ", max(tab)), ""))

ggplot(trace, aes(realtime, class, fill=class, color=class)) +
  geom_violin(alpha=0.5) +
  geom_jitter(alpha=0.5) +
  stat_summary(fun.data=n_fun, geom="text") +
  #stat_summary(fun.data=n_fun, geom="vline", linetype="dashed") +
  xlab("Time (hours)") +
  ylab("") +
  # scale_y_discrete(labels = wrap_format(20)) +
  facet_grid(rows = vars(everything), scales="free", space="free") +
  scale_x_datetime(breaks=make_datetime(0, min=seq(60, 60 * 10, 30)),
                   date_labels = "%H:%M") +
  labs(title="VEP runtimes", subtitle=subtitle, caption=baseline) +
  theme_bw() +
  theme(legend.position = 'none')

traceFile <- tools::file_path_sans_ext(traceFile)
outFile   <- paste0(traceFile, "-runtimes.png")

# Ask to overwrite file, if it exists
owMsg <- sprintf("File %s alreadys exists; aborting.", outFile)
if (file.exists(outFile)) stop(owMsg) 
ggsave(outFile, width=8, height=8)
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
