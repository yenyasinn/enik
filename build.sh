#!/bin/bash

jekyll build

rm -rf docs
cp -r _site docs
echo www.enik.io > docs/CNAME

git add *
now=$(date)
git commit -m "$now"
git push origin master
