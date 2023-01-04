### What's this? 

This set of build scripts allows for the automated building of `atomicdex-API` (mm2) and `atomicdex-Desktop` across various platforms. It consists of one or more parts, including a main batch file for executing from the Jenkins project workspace and a `Dockerfile.*.ci` file for creating a build image with the required build environment. Additionally, the build set may contain a script file that must be executed inside a Docker container to start the build.

The docker images are configured to allow a regular (unprivileged) user, under which Jenkins is run, to execute a build flow. For example, in most build flows using docker, the resulting build command can be executed as `docker run -u $(id -u ${USER}):$(id -g ${USER}) %container_name% %build_command%`.

We always refer to the cloned Github project directory as the "Jenkins workspace". All build scripts must be executed from this workspace.