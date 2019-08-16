#!/bin/bash

jekyll build

rm -rf docs
cp -r _site docs
