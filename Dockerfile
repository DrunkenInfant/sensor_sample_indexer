FROM elixir:1.7.3-alpine as builder

ENV APP_NAME sensor_sample_indexer
ENV SRC_DIR /src/$APP_NAME

RUN apk add --no-cache git curl gawk build-base

RUN mkdir -p $SRC_DIR
WORKDIR $SRC_DIR

ADD mix.exs $SRC_DIR
ADD mix.lock $SRC_DIR

RUN mix local.hex --force
RUN mix local.rebar --force
RUN mix deps.get
RUN mix deps.compile

ADD ./lib $SRC_DIR/lib
ADD ./config $SRC_DIR/config
ADD ./rel $SRC_DIR/rel
ADD ./test $SRC_DIR/test

RUN MIX_ENV=prod mix compile --env=prod
RUN MIX_ENV=prod mix release --env=prod
RUN mkdir -p /tmp/release/$APP_NAME && \
    tar xz \
      -f $SRC_DIR/_build/prod/rel/$APP_NAME/releases/latest/$APP_NAME.tar.gz \
      -C /tmp/release/$APP_NAME

# To figure out which erlang version to run on execute
# docker run --rm elixir:<ELIXIR_VERSION> cat /usr/local/lib/erlang/releases/21/OTP_VERSION
FROM arm32v7/erlang:21.1.1-slim

ENV APP_NAME sensor_sample_indexer

WORKDIR /$APP_NAME

COPY --from=builder /tmp/release /

CMD /$APP_NAME/bin/$APP_NAME foreground
