#!/bin/sh

# run forge tests, then remove tests and samples
forge coverage --report lcov
lcov --remove ./lcov.info 'test/**' 'src/test/**' 'src/samples/**' -o ./lcov.info

# clear old report
rm -rf ./coverage/

# generate new report
mkdir ./coverage/
genhtml --ignore-errors source ./lcov.info --output-directory=./coverage
