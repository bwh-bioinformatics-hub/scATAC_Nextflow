# scATAC_Nextflow

Nextflow Pipeline for the QC, Filtering and Creation of .arrow Files...

## Requirements

```
Installation
This package can be installed from Github using the remotes package.

You may first need to register your GitHub PAT, as this is a private repository.

Sys.setenv(GITHUB_PAT = "your-access-token-here")
remotes::install_github("bwh-bioinformatics-hub/scATAC_Seq_Pipeline")
```
# Install Nextflow
```
wget -qO- https://get.nextflow.io | bash
```
Make the binary executable on your system by running
```
chmod +x nextflow
```


# Metadata Samplesheet example below:
<img src="https://github.com/bwh-bioinformatics-hub/scATAC_Nextflow/blob/main/example_samplesheet.png" width=125% height=90%>

The only column that is a requirement to run the nextflow pipeline is the "Sample" column. 

## Containerization


[Return to Contents](#contents)


