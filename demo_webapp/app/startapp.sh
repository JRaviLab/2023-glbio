#!/usr/bin/env bash

# start running a shiny app on port 5000
R -e "shiny::runApp('/app', host = '0.0.0.0', port = 5000)"
