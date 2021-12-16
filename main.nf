#!/usr/bin/env nextflow
// Benchmark VEP --everything arguments
nextflow.enable.dsl=2

params.repeat = 10 // times to repeat each run

params.vep   = "/hps/software/users/ensembl/repositories/nuno/ensembl-vep/vep"
params.cache = "/nfs/production/flicek/ensembl/variation/data/VEP"
params.fasta = "/nfs/production/flicek/ensembl/variation/data/Homo_sapiens.GRCh38.dna.toplevel.fa.gz"
params.vcf   = "/nfs/production/flicek/ensembl/variation/data/PlatinumGenomes/NA12878.vcf.gz"
params.flags = "vep-everything-flags.txt"

// get flags turned on when setting --everything in VEP
flags = Channel.fromPath( params.flags ).splitText( ).map{it -> it.trim()}

process vep {
    tag "$args $iter"
    publishDir 'logs'

    memory '3 GB'
    executor 'lsf'

    input:
        path vep
        path vcf
        path fasta
        path cache
        val args
        each iter
    output:
        path '*.out'
    """
    name=vep-arg-\$( echo ${args} | sed 's/-//g' | sed 's/ /-/g' )    
    perl ${vep} \
         --i $vcf \
         --o \${name}-\${LSB_JOBID}.txt \
         --offline \
         --cache \
         --dir_cache $cache \
         --assembly GRCh38 \
         --fasta $fasta \
         $args > \${name}-\${LSB_JOBID}-${iter}.out 2>&1
    """
}

workflow {
    // all flags (explicitly stated to check against --everything)
    allFlags = flags.reduce{ a, b -> return "$a $b" }

    // all flags without --regulatory
    nonRegFlags = flags.filter{ it != "--regulatory" }
                       .reduce{ a, b -> return "$a $b" }

    // --everything and no extra flags
    otherFlags = Channel.from( "--everything", "" )

    flagTests = flags.concat( allFlags, nonRegFlags, otherFlags )
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
