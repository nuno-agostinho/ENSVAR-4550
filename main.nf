#!/usr/bin/env nextflow
// Benchmark VEP --everything arguments
nextflow.enable.dsl=2

params.repeat    = 10 // times to repeat each run
params.vep       = "/hps/software/users/ensembl/repositories/nuno/ensembl-vep/vep"
params.cache     = "/nfs/production/flicek/ensembl/variation/data/VEP"
params.fasta     = "/nfs/production/flicek/ensembl/variation/data/Homo_sapiens.GRCh38.dna.toplevel.fa.gz"
params.vcf       = "/nfs/production/flicek/ensembl/variation/data/PlatinumGenomes/NA12878.vcf.gz"

// to pass flags in CLI, add a double-quote and a space in the string
// e.g. nextflow run main.nf --flags "--regulatory "
params.flags     = null 

// params.flagsFile is ignored if params.flags is set
params.flagsFile = "vep-everything-flags.txt"

process vep {
    tag "$args $iter"
    publishDir 'logs'

    memory '3 GB'
    executor 'lsf'
    //clusterOptions "-g ENSVAR-4550"

    input:
        path vep
        path vcf
        path fasta
        path cache
        val args
        each iter
    output:
        path '*.out' optional true
    """
    name=vep-arg-\$( echo ${args} | sed 's/-//g' | sed 's/ /-/g' )
    log=\${name}-\${LSB_JOBID}-${iter}.out
    perl ${vep} \
         --i $vcf \
         --o \${name}-\${LSB_JOBID}.txt \
         --offline \
         --cache \
         --dir_cache $cache \
         --assembly GRCh38 \
         --fasta $fasta \
         $args > \${log} 2>&1

    # remove log file if empty
    [ -s \${log} ] || rm \${log}
    """
}

workflow {
    if ( params.flags ) {
        flagTests = Channel.of( params.flags )
    } else {
        // get flags turned on when setting --everything in VEP
        flags = Channel.fromPath( params.flagsFile )
                       .splitText()
                       .map{it -> it.trim()}

        // all flags (explicitly stated to check against --everything)
        allFlags = flags.reduce{ a, b -> return "$a $b" }

        // all flags without --regulatory
        nonRegFlags = flags.filter{ it != "--regulatory" }
                           .reduce{ a, b -> return "$a $b" }

        // no extra flags (baseline) and --everything
        otherFlags = Channel.from( "--everything", "" )
        flagTests = allFlags.concat( nonRegFlags, otherFlags, flags )
    }
    loop = Channel.from(1..params.repeat)
    vep( params.vep, params.vcf, params.fasta, params.cache, flagTests, loop )
}

// Print summary
workflow.onComplete {
    println ( workflow.success ? """
        Workflow summary
        ----------------
        Completed at: ${workflow.complete}
        Duration    : ${workflow.duration}
        Success     : ${workflow.success}
        workDir     : ${workflow.workDir}
        exit status : ${workflow.exitStatus}
        """ : """
        Failed: ${workflow.errorReport}
        exit status : ${workflow.exitStatus}
        """
    )
}
