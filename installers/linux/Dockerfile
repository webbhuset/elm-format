# Static Linux build of elm-format, for the release workflow. Alpine links
# against musl, so the binary runs on any Linux whatever its libc.
#
# generated/Build_elm_format.hs is stamped on the host by
# installers/stamp-version.sh; the container has no git history to derive it
# from.

# 3.20 for musl 1.2.5: the arm64 GHC 9.6.7 that ghcup offers needs its statx.
FROM alpine:3.20

# ghcup's own list of what GHC needs, plus the static libraries.
RUN apk add --no-cache curl pkgconfig build-base musl-dev zlib-dev zlib-static gmp-dev ncurses-dev ncurses-static libffi-dev binutils-gold perl tar xz

WORKDIR /elm-format

ARG GHCUP_INSTALL_BASE_PREFIX=/elm-format
ARG PATH="${PATH}:/elm-format/.ghcup/bin"
RUN curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | BOOTSTRAP_HASKELL_NONINTERACTIVE=1 BOOTSTRAP_HASKELL_MINIMAL=1 sh
# On failure ghcup says only which command failed; its log says why.
RUN ghcup install ghc --set 9.6.7 || (cat .ghcup/logs/*; exit 1)
RUN ghcup install cabal --set 3.16.1.0 || (cat .ghcup/logs/*; exit 1)

RUN cabal update

COPY cabal.project cabal.project.freeze elm-format.cabal ./
COPY avh4-lib avh4-lib
COPY elm-format-markdown elm-format-markdown
COPY elm-format-lib elm-format-lib
COPY elm-format-test-lib elm-format-test-lib
COPY Shakefile Shakefile
COPY src src
COPY generated generated

RUN cabal build elm-format --enable-executable-static --ghc-option=-split-sections
RUN cp "$(cabal list-bin elm-format)" /usr/local/bin/elm-format
RUN strip -s /usr/local/bin/elm-format
