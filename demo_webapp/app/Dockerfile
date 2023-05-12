FROM --platform=linux/amd64 rocker/shiny-verse:4.2.2

ENV BIOCONDUCTOR_VERSION 3.16

COPY ./install.R /tmp/install.R
RUN Rscript /tmp/install.R

# install small "extras", so we don't invalidate the previous lengthy layer's
# build cache
COPY ./install_extras.R /tmp/install_extras.R
RUN Rscript /tmp/install_extras.R

# also install rintepro from github
RUN R -e 'devtools::install_github("JRaviLab/iprscanr", dependencies = TRUE, quick = TRUE)'

# # alternatively, install it from a local folder until rinterpro becomes public
# COPY ./external-libs /tmp/external-libs
# RUN R -e 'devtools::install("/tmp/external-libs/rinterpro", dependencies = TRUE)'

# set the working directory to a folder that shiny-server can serve
WORKDIR /srv/shiny-server/app

# copy in the app code; this is last so that changes to the app don't invalidate
# prior layers where we do expensive things like build/install software
COPY . .
