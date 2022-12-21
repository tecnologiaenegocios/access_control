FROM ruby:2.4.6-alpine3.9

ENV APP_ROOT /app

# - build-essential: To ensure certain gems can be compiled
# - nodejs: Compile assets
# - libmariadbd-dev: MariaDB development files

RUN mkdir -p $APP_ROOT
WORKDIR $APP_ROOT

RUN apk add --no-cache --update build-base \
                                linux-headers \
                                bash \
                                less \
                                git \
                                mariadb \
                                mariadb-dev \
                                mariadb-client \
                                sqlite-dev \
                                sqlite

COPY . .

RUN bundle install --binstubs
