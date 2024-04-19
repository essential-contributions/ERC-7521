#!/bin/sh

# run forge tests, then remove tests and samples
forge coverage --report lcov
lcov --remove ./lcov.info 'test/**' 'contracts/test/**' 'contracts/samples/**' 'contracts/utils/**' 'contracts/interfaces/**' -o ./lcov.info

# clear old report
rm -rf ./coverage/

# generate new report
mkdir ./coverage/
genhtml --title "ERC-7521 Coverage" --ignore-errors source ./lcov.info --output-directory=./coverage
