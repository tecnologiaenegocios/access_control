#!/bin/bash

set -e

if ! bundle check > /dev/null; then
  echo "Gems dependencies are out of date. Installing..."
  bundle install --binstubs
fi

exec "$@"
