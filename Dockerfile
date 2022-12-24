FROM ruby:2.3.3-alpine

ENV APP_ROOT /app
RUN mkdir -p $APP_ROOT
WORKDIR $APP_ROOT

RUN apk add --no-cache --update build-base \
                                linux-headers \
                                bash \
                                less \
                                git \
                                mariadb-dev \
                                mariadb-client \
                                sqlite-dev \
                                sqlite

COPY . .
RUN bundle install --binstubs
