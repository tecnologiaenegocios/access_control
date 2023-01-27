FROM ruby:2.3.3-alpine

ENV APP_ROOT /app
RUN mkdir -p $APP_ROOT
WORKDIR $APP_ROOT

RUN apk add --no-cache --update \
  bash \
  build-base \
  git \
  less \
  linux-headers \
  mariadb-client \
  mariadb-dev \
  ncurses \
  readline \
  sqlite \
  sqlite-dev

COPY . .
