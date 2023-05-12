if (!require("BiocManager", quietly = TRUE))
    install.packages("BiocManager")

install.packages(c("ggplot"))

library(BiocManager)

BiocManager::install(version = Sys.getenv("BIOCONDUCTOR_VERSION"), ask = FALSE)

pkgs <- c(
    "Biostrings",
    "httr"
)

ok <- BiocManager::install(pkgs=pkgs, ask=FALSE, force=TRUE) %in% rownames(installed.packages())

if (!all(ok)) {
    print("Some packages failed to install, aborting...")
    quit(status=1)
}
