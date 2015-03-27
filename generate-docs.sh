#!/bin/bash
#
#  Build documentation using jazzy:
#    [sudo] gem install jazzy

jazzy \
	-a "Pascal Pfiffner" \
	-u "http://www.github.com/p2" \
	-m "OAuth2" \
	-g "https://github.com/p2/OAuth2" \
	-r "http://p2.github.io/OAuth2" \
	-o "docs" \
	--module-version "1.0"
