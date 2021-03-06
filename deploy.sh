#!/bin/bash
# 参考 https://zhuanlan.zhihu.com/p/37752930

echo -e "\033[0;32mDeploying updates to GitHub...\033[0m"


PUBLISH_BRANCH="gh-pages"

if [[ $(git status -s) ]]
then
    echo "The working directory is dirty. Please commit any pending changes."
    exit 1;
fi

echo "Deleting old publication"
rm -rf public
mkdir public
rm -rf .git/worktrees/public/

echo "Checking out gh-pages branch into public"
git worktree add -B ${PUBLISH_BRANCH} public origin/${PUBLISH_BRANCH}

echo "Removing existing files"
rm -rf public/*

echo "Generating site"
hugo

echo "Updating gh-pages branch"
cd public && git add --all && git commit -m "Publishing ${PUBLISH_BRANCH}"

echo "Push to origin"
git push origin ${PUBLISH_BRANCH}

function create_gh() {
	git checkout --orphan gh-pages
	git rm -fr *
	git commit --allow-empty -m "Initializing gh-pages branch"
	git push origin gh-pages
}
