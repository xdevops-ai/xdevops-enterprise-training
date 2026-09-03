ARG POSTGRES_BASE_IMAGE=postgres:16-alpine
FROM ${POSTGRES_BASE_IMAGE}
# Official postgres:alpine creates the postgres user/group as UID/GID 70.
# The training bootstrap only runs psql, so it does not need the root entrypoint path.
USER 70:70
