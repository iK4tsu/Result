#!/usr/bin/env sh
dmd -unittest -debug -g -betterC -I=source -i -run testbetterc.d
