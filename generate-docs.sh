#!/bin/bash
#
#  Build documentation using jazzy:
#    [sudo] gem install jazzy

jazzy \
	-o "docs" \
	--min-acl "internal" \
	--module-version "3.0.3"

mkdir docs/assets 2>/dev/null
cp assets/* docs/assets/
