#!/bin/bash

# Redirect standard output and standard error
exec > >(trap "" INT TERM; sed $'s/^/[\033[0;35mXCODE\033[0m]/')
exec 2> >(trap "" INT TERM; sed $'s/^/[\033[0;35mXCODE\033[0m]/' >&2)

# Sample outputs
echo "This is a standard output message."
echo "This is an error message." >&2
