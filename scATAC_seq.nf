#!/usr/bin/ nextflow

nextflow.enable.dsl=1

/*
========================================================================================
   QC Report Generator Nextflow Workflow
========================================================================================
   Github   : 
   Contact  :     
----------------------------------------------------------------------------------------
*/


Channel
    .fromPath( params.samples_csv )
    .splitCsv( header: true, sep: ',' )
    .map { row ->  row.sample_id }
    .set { sample_id_ch }

(sample,samples,sample_id,sid,sampleid,id,sam_id) = sample_id_ch.into(7)


println """\
         sc ATAC Seq - N F   P I P E L I N E
         ===================================
         Experiment                : ${params.experiment_id}
         Samplesheet        	     : ${params.in_key}
         CellRangersOuts Directory : ${params.cellrangers_outdir}
         QC Report input directory : ${params.qc_in_dir}
         QC Report Output directory: ${params.qc_output}
         """
         .stripIndent()

process Arc_Formatting {

  publishDir (
        path: "${params.outdir}",
        mode: 'copy',
        overwrite: 'true',
  )	
        
    input:
    each sample 
    output: 
    
    path("${sample}/${sample}_arc_formatting_report.html") into qc_summary
    path("${sample}/arc_singlecell.csv") into arc_singlecell
    path("${sample}/atac_summary.csv") into atac_summary

    script:

  """
    mkdir -p ${sample}
    Rscript ${baseDir}/scripts/00_run_arc_format.R -t ${params.cellrangers_outs_dir}/${sample}/outs/  -d ${sample} -o ${sample}/${sample}_arc_formatting_report.html 
  """

}

process Preprocessing {
    publishDir (
        path: "${params.outdir}/${sample_id}/preprocessed/",
        mode: 'copy',
        overwrite: 'true',
  )	

  input:
    file(in_qc) from qc_summary.collect()
    each sample_id

  output:
  file("${sample_id}_*.gz") into preprocessed

  script:

  """
  bash /mnt/data0/projects/biohub/development/scATAC/nextflow_development/scripts/01_crossplatform_preprocessing.sh \
  -b /mnt/data0/projects/biohub/software/bedtools2/bin/bedtools \
  -i /mnt/data0/projects/biohub/development/scATAC/nextflow_development/data/${sample_id}/outs/atac_fragments.tsv.gz \
  -g hg38 \
  -j 16 \
  -o . \
  -q FALSE  \
  -s /mnt/data0/projects/biohub/development/scATAC/nextflow_development/results/${sample_id}/arc_singlecell.csv \
  -t atac_preprocessing_temp \
  -w ${sample_id}

  """
}

process CrossPlatform {
      publishDir (
        path: "${params.outdir}",
        mode: 'copy',
        overwrite: 'false',
  )	

  input:
  path(data_processed) from preprocessed.collect()
  each samples

  output:
  path("${samples}/atac_qc/*") into atac_qc

  script:
  """
  mkdir -p ${samples}/atac_qc/
  Rscript ${baseDir}/scripts/02_run_crossplatform_atac_qc.R -p ${baseDir}/results/${samples}/preprocessed \
  -t ${params.cellrangers_outs_dir}/${samples}/outs/ \
  -k ${params.samples_csv} \
  -s ${samples} \
  -j ${baseDir}/results/${samples}/ \
  -g hg38 \
  -q TRUE \
  -d ${samples}/atac_qc/ \
  -o ${samples}/atac_qc/${samples}_qc_report.html
  
  Rscript ${baseDir}/scripts/03_scatac_qc_script.R \ -s ${samples} \
  -m 'scatac' \
  -i ${baseDir}/results/${samples}/ \
  -k ${params.samples_csv} \
  -d ${samples}/atac_qc/\
  -o ${samples}/atac_qc/${samples}_atac_qcreport.html
  
  """
}

  process filter_frags {
    publishDir (
        path: "${params.outdir}/${sid}/atac_qc/",
        mode: 'copy',
        overwrite: 'true',
  )	

    input:

    path(report) from atac_qc.collect()
    each sid

    output:
    file("${sid}_filtered_fragments.tsv.gz") into filtered_frags

    script:
    """
    bash ${baseDir}/scripts/04_filter_fragments.sh \
    -i /mnt/data0/projects/biohub/development/scATAC/nextflow_development/data/BN1848SN/outs/atac_fragments.tsv.gz \
    -m ${baseDir}/results/${sid}/atac_qc/${sid}_filtered_metadata.csv.gz \
    -j 32 \
    -o . \
    -t atac_qc/filtering_temp/ \
    -s ${sid}
    """
  }

 process post_processing {

        publishDir (
        path: "${params.outdir}",
        mode: 'copy',
        overwrite: 'false',
  )	

  input: 
  each sampleid 
  path(filtered_fragments) from filtered_frags.collect()

  output: 
  path("${sampleid}/postprocessed/*") into post_processed

  script:

  """
  mkdir -p ${sampleid}/postprocessed
  bash ${baseDir}/scripts/05_crossplatform_postprocessing.sh -b /mnt/data0/projects/biohub/software/bedtools2/bin/bedtools \
  -i ${baseDir}/results/${sampleid}/atac_qc/${sampleid}_filtered_fragments.tsv.gz \
  -g hg38 \
  -j 16 \
  -m ${baseDir}/results/${sampleid}/atac_qc/${sampleid}_filtered_metadata.csv.gz \
  -o ${sampleid}/postprocessed \
  -t atac_postprocessing_temp \
  -s ${sampleid}
  """
 }

 process assemble_atac_frags {

  publishDir (
  path: "${params.outdir}",
  mode: 'copy',
  overwrite: 'false',
  )	

  input:
  each sam_id
  path(processed) from post_processed.collect()

  output:
  path("${sam_id}_qc_report.html") into assembled
  """
  Rscript ${baseDir}/scripts/06_run_assemble_atac_outputs.R \
  -p ${baseDir}/results/${sam_id}/postprocessed \
  -f ${baseDir}/results/${sam_id}/atac_qc/${sam_id}_filtered_fragments.tsv.gz \
  -m ${baseDir}/results/${sam_id}/atac_qc/${sam_id}_filtered_metadata.csv.gz \
  -g hg38 \
  -d . \
  -o ${sam_id}_qc_report.html
  """
 }

