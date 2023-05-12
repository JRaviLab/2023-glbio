#
# This Shiny webapp demonstrates using the library we created before,
# iprscanr, and wrapping it in a web interface to make interacting with
# it easier.
#

# load up some required libraries, notably shiny and some other bits for
# rendering datatables and async processing
library(shiny)
library(DT)
library(promises)
library(future)

# fyi, library(dotenv) reads the .env file into the environment
library(dotenv)

# here we load our own library, previously installed in the Dockerfile
library(iprscanr)


# =============================================================================
# === constants, helper functions
# =============================================================================

# get user email from environment (implicitly from .env)
USER_EMAIL <- Sys.getenv("USER_EMAIL")

# set future to use multisession mode
plan(multisession)

# supply some default text to fill in the box when "load example" is pressed
DEFAULT_FASTA_TEXT <-
    ">ANY95992.1 protein LiaH [Bacillus altitudinis]
MVLRRVRDMFVATVNEGLDKLENPRVMLNQYVRDMEDDIAKAKHAIIKQQTIQQGFL
RKAEETEAFADKRKKQAELAFQAGEEELVRKALTEMKYFEEKHNEYQEAYQQSVKQL
KELKEQLQHLETKLRDVKDKKQALIARANAAQAKQHMNESMNKVDSESAYKEFLRM
ENRIEEMETKAGSYAQFADQGAYAHLDYADEVEKEWQKLQRSKQPEKQPAN"

# helper function for writing to stderr, where it'll be visible from the server log
console_stderr <- function(x) {
    cat(file = stderr(), x, "\n")
}

# main worker function that submits a string of FASTA data to InterProScan via
# the iprscanr package, and returns the resulting classifications as a dataframe
get_input_and_submit_ipr <- function(input_fasta) {
    # put the input into a temp file
    tmp_fasta_in <- tempfile()
    write(input_fasta, tmp_fasta_in)

    # create a destination for the output, too
    tmp_results_out <- tempdir()

    # start the submission, recording the time it took to run
    start_time <- Sys.time()
    results_folder <- submit_ipr(tmp_fasta_in, tmp_results_out, USER_EMAIL)
    end_time <- Sys.time()

    # get total duration as human readable duration, e.g. MM:SS
    dur <- lubridate::as.period(end_time - start_time)
    total_time <- sprintf(
        '%02d:%02d',
        as.integer(lubridate::minute(dur)), as.integer(lubridate::second(dur))
    )

    # find and return a list of every TSV in the results folder
    results_files <- list.files(results_folder, pattern = "*.tsv", full.names = TRUE)

    # read each TSV into a dataframe, annotated with header info
    results_dfs <- lapply(results_files, function(tsv_path) {
        df <- read.table(
            tsv_path, sep = "\t", header = FALSE, stringsAsFactors = FALSE,
            col.names = c(
                "Protein accession",
                "Sequence MD5 digest",
                "Sequence length",
                "Analysis",
                "Signature accession",
                "Signature description",
                "Start Loc", "Stop Loc",
                "Score", "Status", "Date",
                "IPR Accession", "IPR Description"
            )
        )

        return(list(filename=tsv_path, data=df))
    })

    # create results object w/status and dataframes
    return(
        list(
            "status"=list(
                "total_time"=total_time,
                "results_folder"=results_folder
            ),
            "dataframes"=results_dfs
        )
    )
}


# =============================================================================
# === UI definition
# =============================================================================

ui <- fluidPage(
    # Application title
    titlePanel("iprscanr Demo App"),

    # Sidebar with a slider input for number of bins
    sidebarLayout(
        sidebarPanel(
            textAreaInput("interpro_input", "Enter FASTA data", rows = 10),

            fluidRow(
                actionButton("interpro_submit", "Run InterProScan"),
                actionButton("load_example", "Load Example FASTA")
            ),

            width=5
        ),

        # display resulting tables from interproscan
        mainPanel(
            # shinycssloaders::withSpinner(
            #     textOutput("status_out")
            # ),

            textOutput("status_out"),
            uiOutput("results_dts"),

            width=7
        )
    )
)


# =============================================================================
# === server logic
# =============================================================================

server <- function(input, output) {
    results <- reactiveValues()
    results$status <- NULL
    results$dataframes <- NULL

    # when the submit button is pressed, submit the input to interproscan
    observeEvent(input$interpro_submit,
        {
            start_msg <- "Running InterProScan..."
            console_stderr(start_msg)
            output$status_out <- renderText(start_msg)

            submitted_fasta <- isolate(input$interpro_input)

            future_promise({
                return(get_input_and_submit_ipr(submitted_fasta))
            }) %...>% (function(promise_results) {
                # write out debug output
                console_stderr(paste(promise_results))

                # format duration in minutes as a human-readable duration
                duration <- promise_results$status$total_time

                # write out a success message
                complete_msg <- paste0("Complete! Took ", promise_results$status$total_time)
                console_stderr(complete_msg)
                output$status_out <- renderText(complete_msg)

                # and finally update the reactive value that'll render the dataframes
                results$status <- promise_results$status
                results$dataframes <- promise_results$dataframes
            })
        },
        ignoreInit = TRUE,
        ignoreNULL = TRUE
    )

    # render the set of dataframes returned from ipr_submit as DT datatables
    output$results_dts <- renderUI({
        df_list = tagList()

        console_stderr("In output$results_dts <- renderUI(...)")
        console_stderr(paste(results$dataframes))

        if (!is.null(results$dataframes) && length(results$dataframes) > 0) {
            for (idx in 1:length(results$dataframes)) {
                cur_elem <- results$dataframes[[idx]]
                console_stderr(paste0("* Processing IDX [[", idx, "]]] = ", paste(cur_elem), "\n"))

                df_list[[idx]] = tagList()
                df_list[[idx]][[1]] = h3(paste0("Table ", cur_elem$filename))
                df_list[[idx]][[2]] <- DT::renderDataTable(cur_elem$data)
            }
        }

        # df_list[[length(df_list) + 1]] = h3("End?")

        return(df_list)
    })

    # loads the default input text when the "load example" button is pressed
    observeEvent(
        input$load_example,
        { updateTextInput(inputId = "interpro_input", value = DEFAULT_FASTA_TEXT) },
        ignoreInit = TRUE
    )
}


# =============================================================================
# === entrypoint
# =============================================================================

console_stderr("* Application Started")

# retain the stdout log
if (!interactive()) sink(stderr(), type = "output")

shinyApp(ui = ui, server = server)
