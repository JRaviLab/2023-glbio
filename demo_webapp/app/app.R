#
# This Shiny webapp demonstrates using the library we created before,
# iprscanr, and wrapping it in a web interface to make interacting with
# it easier.
#

# load up some required libraries, notably shiny and some other bits for
# rendering datatables and async processing
library(shiny)
library(shinyjs)
library(shinycssloaders)
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

# supply some default text to fill in the box when "load example" buttons are pressed
single_fasta_example <- system.file(package = "iprscanr", "extdata", "ex-in-CAA75348.1.faa")
multi_fasta_example <- system.file(package = "iprscanr", "extdata", "ex-in-2.faa")

# helper function for writing to stderr, where it'll be visible from the server log
console_stderr <- function(x) {
    cat(file = stderr(), x, "\n")
}

setControlStatus <- function(is_enabled) {
    set_func <- ifelse(is_enabled, enable, disable)
    set_func("interpro_input")
    set_func("interpro_submit")
    set_func("load_single_example")
    set_func("load_multi_example")
}

# =============================================================================
# === UI definition
# =============================================================================

ui <- fluidPage(
    useShinyjs(),

    # Application title
    titlePanel("iprscanr Demo App"),

    # Sidebar with a slider input for number of bins
    sidebarLayout(
        sidebarPanel(
            textAreaInput("interpro_input", "Enter FASTA data", rows = 10),

            fluidRow(
                actionButton("interpro_submit", "Run InterProScan", class = "btn-success"),
                actionButton("load_single_example", "Load Example Single-Sequence FASTA"),
                actionButton("load_multi_example", "Load Example Multi-Sequence FASTA")
            , style="margin-left: 0px;"),

            width=12
        ),

        # display resulting tables from interproscan
        mainPanel(
            div(
                # textOutput("status_out"),
                htmlOutput(outputId = 'status_out')
            , style="margin-bottom: 20px;"),

            tabsetPanel(
                tabPanel("Results", 
                    withSpinner(
                        DT::dataTableOutput("ipr_results")
                    ),
                    style="padding: 20px; overflow-x: scroll;"
                ),
                tabPanel("Runtime Info",
                    withSpinner(
                        plotOutput("runtime_plot")
                        # uiOutput("runtime_output")
                    ),
                    style="padding: 20px;"
                )
            ),

            width=12
        )
    )
)


# =============================================================================
# === server logic
# =============================================================================

# main worker function that submits a string of FASTA data to InterProScan via
# the iprscanr package, and returns the resulting classifications as a dataframe
get_input_and_submit_ipr <- function(input_fasta) {
    # ensure our output makes it to stderr
    if (!interactive()) sink(stderr(), type = "output")

    # put the input into a temp file, and output into a temp directory
    tmp_fasta_in <- tempfile(); write(input_fasta, tmp_fasta_in)
    tmp_out_dir <- tempdir()

    # start the submission, recording the time it took to run
    start_time <- Sys.time()
    ipr_results <- submit_ipr(tmp_fasta_in, tmp_out_dir, USER_EMAIL)
    end_time <- Sys.time()

    console_stderr("Final Output:")
    console_stderr(capture.output(dput(ipr_results)))

    # get total duration as human readable duration, e.g. MM:SS
    dur <- lubridate::as.period(end_time - start_time)
    total_time <- sprintf('%02d:%02d', as.integer(lubridate::minute(dur)), as.integer(lubridate::second(dur)))

    # create results object w/status and data
    return(
        list(
            "status"=list(
                "total_time"=total_time,
                "job_dir"=tmp_out_dir # used to fetch the job runtime histogram
            ),
            "data"=ipr_results
        )
    )
}

server <- function(input, output) {
    output$ipr_results <- NULL
    output$runtime_plot <- NULL
    output$status_out <- renderText({ "" })

    hist_values <- reactiveValues()
    hist_values$data <- NULL
    hist_values$job_dir <- NULL

    # when the submit button is pressed, submit the input to interproscan
    observeEvent(input$interpro_submit, {
        setControlStatus(FALSE)

        # reset the histogram plot
        hist_values$data <- NULL
        hist_values$job_dir <- NULL

        start_msg <- "Running InterProScan (this may take a minute or two)..."
        console_stderr(start_msg)
        shinyjs::html(id = 'status_out', html = start_msg)

        submitted_fasta <- isolate(input$interpro_input)

        output$ipr_results <- renderDT({
            future_promise({
                get_input_and_submit_ipr(submitted_fasta)
            }) %...>% (function(promise_results) {
                # write out a success message
                complete_msg <- paste0("Complete! Runtime: ", promise_results$status$total_time)
                console_stderr(complete_msg)
                shinyjs::html(id = 'status_out', html = complete_msg)

                # set the histogram plot and other relevant bits, too
                hist_values$data <- promise_results$hist_plot
                hist_values$job_dir <- promise_results$status$job_dir

                # re-renable the submit button
                setControlStatus(TRUE)

                promise_results$data
            }) %...T!% (function(err) {
                shinyjs::html(id = 'status_out', html = toString(err))
                setControlStatus(TRUE)
            })
        })
    }, ignoreInit = TRUE)

    output$runtime_plot <- renderPlot({
        result <- NULL

        tryCatch({
            result <- job_time_hist(file.path(hist_values$job_dir, "api.log"))
        }, error = function(e) {
            console_stderr("Error generating runtime plot:")
            console_stderr(toString(e))
            result <- FALSE
        })

        return(result)
    })

    # output$runtime_output <- renderUI({
    #     if (output$runtime_plot == FALSE) {
    #         p(
    #             "Error generating runtime plot, likely because only one sequence was supplied",
    #             style="font-style: italic; text-align: center; padding: 20px;"
    #         )
    #     }
    #     else {
    #         plotOutput("runtime_plot")
    #     }
    # })

    # set up load example buttons
    observeEvent( input$load_single_example, {
        file_data <- paste(readLines(single_fasta_example), collapse = "\n")
        updateTextInput(inputId = "interpro_input", value = file_data)
    }, ignoreInit = TRUE)
    observeEvent( input$load_multi_example, {
        file_data <- paste(readLines(multi_fasta_example), collapse = "\n")
        updateTextInput(inputId = "interpro_input", value = file_data)
    }, ignoreInit = TRUE)
}


# =============================================================================
# === entrypoint
# =============================================================================

console_stderr("* Application Started")

# ignore RNG errors
options(future.rng.onMisuse="ignore")
options(error = function() traceback(3))

# retain the stdout log
if (!interactive()) sink(stderr(), type = "output")

shinyApp(ui = ui, server = server)
