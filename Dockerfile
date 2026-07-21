# syntax=docker/dockerfile:1

FROM alpine:3.23

# Only the two things git-restore-mtime needs at runtime.
RUN --mount=type=cache,target=/var/cache/apk apk add python3 git

# Git ref (tag, branch, or commit) of MestreLion/git-tools to install.
# Override for latest changes, e.g. --build-arg GIT_TOOLS_REF=main
ARG GIT_TOOLS_REF=v2025.08

# Needs to be updated if using a different GIT_TOOLS_REF. eg:
#  $ export GIT_TOOLS_REF=main
#  $ export GIT_RESTORE_MTIME_CHECKSUM=$(curl -s "https://raw.githubusercontent.com/MestreLion/git-tools/${GIT_TOOLS_REF}/git-restore-mtime" | openssl dgst -sha256 -binary | xxd -p -c0)
#  $ docker build --build-arg GIT_TOOLS_REF --build-arg GIT_RESTORE_MTIME_CHECKSUM .
ARG GIT_RESTORE_MTIME_CHECKSUM=8cdae72ea524e7c79c5a61bdfb5004cdab0082074f5fb558f1dba270f91e26b2
ADD --chmod=755 \
    --checksum=sha256:${GIT_RESTORE_MTIME_CHECKSUM} \
    https://raw.githubusercontent.com/MestreLion/git-tools/${GIT_TOOLS_REF}/git-restore-mtime /usr/local/bin/git-restore-mtime

# Configure git to allow running in any directory, including mounted volumes.
RUN git config --system --add safe.directory '*'

# Repositories are expected to be mounted here.
WORKDIR /workdir

ENTRYPOINT ["git-restore-mtime"]
CMD ["--help"]
