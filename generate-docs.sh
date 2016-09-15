#!/bin/bash
#
#  Build documentation using jazzy:
#    [sudo] gem install jazzy

jazzy \
	-o "docs" \
	--module-version "3.0.0"

mkdir docs/assets 2>/dev/null
cp assets/* docs/assets/
