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
    .map { row ->  row.Sample_ID }
    .set { sample_id_ch }

(sample,samples,sample_id,sid,sampleid,id) = sample_id_ch.into(6)


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
        overwrite: 'true',
  )	

  input:
  path(data_processed) from preprocessed.collect()
  each samples

  output:
  path("${samples}/atac_qc") into atac_qc

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
  """
}

process qc {

  publishDir(
    path: "${params.outdir}/${id}/qc_report",
    mode: 'copy',
    overwrite: 'true'
  )

  input:
  path(qc) from atac_qc.collect()
  each id 
  output:
  path("${id}_atac_qcreport.html") into qc_report

  script:
  """
  Rscript ${baseDir}/scripts/03_scatac_qc_script.R \ 
  -s ${id} \
  -m 'scatac' \
  -i ${baseDir}/results/${id}/ \
  -k ${params.samples_csv} \
  -d . \
  -o ${id}_atac_qcreport.html
  """

}
  process filter_frags {

        publishDir (
        path: "${params.outdir}",
        mode: 'copy',
        overwrite: 'true',
  )	

    input:
    each sid
    path(q) from qc_report.collect()

    output:
    path("${sid}/atac_qc/*") into filtered_frags

    script:
    """
    bash ${baseDir}/scripts/04_filter_fragments.sh \
    -i ${baseDir}/results/${sid}/outs/atac_fragments.tsv.gz \
    -m ${baseDir}/results/${sid}/atac_qc/${sid}_filtered_metadata.csv.gz \
    -j 32 \
    -o ${sid}/atac_qc/ \
    -t filtering_temp/ \
    -s ${sid}
    """
  }

 process post_processing {

        publishDir (
        path: "${params.outdir}",
        mode: 'copy',
        overwrite: 'true',
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
