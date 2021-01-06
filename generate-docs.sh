#!/bin/bash
#
#  Build documentation using jazzy:
#    [sudo] bundle install

bundle exec jazzy \
	-o "docs" \
	--min-acl "internal" \
	--module-version "5.3.1"

mkdir docs/assets 2>/dev/null
cp assets/* docs/assets/
