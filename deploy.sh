#!/bin/bash

if [[ $(git status -s) ]]
then
    echo "The working directory is dirty. Please commit any pending changes."
    exit 1;
fi

echo "deploy github"
bash ./deploy_remote.sh

echo "deploy gitee pages"
bash ./deploy_remote.sh gitee gitee-pages