FROM elixir:1.10-alpine AS build

RUN adduser -D lichat
USER lichat
# the default (SIGTERM) lands you into the Erlang debugger
STOPSIGNAL SIGQUIT

ENV MIX_ENV=prod

RUN mix local.hex --force --if-missing && \
    mix local.rebar --force --if-missing

COPY --chown=lichat:lichat \
    mix.exs mix.lock \
    /home/lichat/ex-lichat/

WORKDIR /home/lichat/ex-lichat

RUN mix deps.get && \
    mix deps.compile

COPY --chown=lichat:lichat config ./config
COPY --chown=lichat:lichat lib ./lib
COPY --chown=lichat:lichat test ./test
COPY --chown=lichat:lichat rel ./rel

RUN touch -a config/secret.exs && \
    mix release

FROM elixir:1.10-alpine AS run

RUN adduser -D lichat
USER lichat
STOPSIGNAL SIGQUIT

COPY --from=build /home/lichat/ex-lichat/_build/prod/rel/ /opt/
WORKDIR /opt/lichat
COPY --chown=lichat:lichat \
    config/banner.txt config/blacklist.txt config/cert.pem config/key.pem \
    var/config/
RUN mkdir var/data/ var/emotes/ && \
    ln -sT var/data data && \
    ln -sT var/emotes emotes && \
    ln -sT var/config config
VOLUME ["/opt/lichat/var/"]
CMD ["./bin/lichat", "start"]
EXPOSE 1111-1112
