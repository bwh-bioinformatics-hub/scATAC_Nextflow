hg19_genome <- system.file("reference/hg19.chrom.sizes", package = "ATAComb")
file.copy(hg19_genome, "reference/hg19.chrom.sizes")

hg19_ref_files <- list.files(system.file("reference", package = "ATAComb"),
                             pattern = "hg19.+.bed.gz",
                             full.names = TRUE)
hg19_ref_names <- sub(".+/","",hg19_ref_files)
file.copy(hg19_ref_files,
          file.path("reference", hg19_ref_names),
          overwrite = TRUE)

hg38_genome <- system.file("reference/hg38.chrom.sizes", package = "ATAComb")
file.copy(hg38_genome, "reference/hg38.chrom.sizes")

hg38_ref_files <- list.files(system.file("reference", package = "ATAComb"),
                             pattern = "hg38.+.bed.gz",
                             full.names = TRUE)
hg38_ref_names <- sub(".+/","",hg38_ref_files)
file.copy(hg38_ref_files,
          file.path("reference", hg38_ref_names),
          overwrite = TRUE)

