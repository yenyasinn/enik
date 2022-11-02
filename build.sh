#!/bin/bash

bundle exec jekyll build

rm -rf docs
cp -r _site docs
cp sitemap.xml docs/sitemap.xml
cp .nojekyll docs/.nojekyll
echo www.enik.pro > docs/CNAME

git add *
now=$(date)
git commit -m "$now"
git push origin master
