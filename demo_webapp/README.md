# Demo Webapp for iprscanr

This folder contains implementation for a Shiny web application that runs on
shiny-server, within a Docker container. First, copy `./app/env.TEMPLATE` as
`./app/.env` and update the variable `USER_EMAIL` to an email address you own.
Then, you can build and run the application using the `build_and_run.sh` script.

The process, running from this folder, would be:

```bash
cp ./app/.env.TEMPLATE ./app/.env
nano ./app/.env # or whichever editor you prefer
./buld_and_run.sh
```

Once the image has been built and the container is running, you'll see a line
similar to the following at the end of the output:

```
[2023-05-12T20:24:27.252] [INFO] shiny-server - Starting listener on http://[::]:3838
```

At that point, you can browse to http://localhost:3838/app to view the app. The
first time you access it, it may take a while, but subsequent accesses should be
quick.

Regarding development, any changes you make to code within `./app/` will be
reflected in the running webapp after you refresh your browser.
