#!/bin/bash

if [ "$TRAVIS_PULL_REQUEST" != "false" ]; then
  exit 0
fi

if [ -z "${GH_EMAIL}" ]; then
  echo "GH_EMAIL not set"
  exit 1
fi
if [ -z "${GH_USER}" ]; then
  echo "GH_USER not set"
  exit 1
fi
if [ -z "${GH_PASSWORD}" ]; then
  echo "GH_USER not set"
  exit 1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$DIR"/../..

COMMITTAG="[AUTO][ci skip]: updating cocos2dx_files.json"
PUSH_REPO="https://api.github.com/repos/cocos-creator/cocos2d-x-lite/pulls"
OUTPUT_FILE_PATH="${PROJECT_ROOT}/templates/cocos2dx_files.json"
FETCH_REMOTE_BRANCH=$1
COMMIT_PATH="templates/cocos2dx_files.json"

# Exit on error
set -e

generate_cocosfiles_json()
{
    echo "Updates cocos_files.json"
    ./generate-template-files.py
}

generate_cocosfiles_json

pushd "$PROJECT_ROOT"
#Set git user for cocos2d-x repo
git config user.email ${GH_EMAIL}
git config user.name ${GH_USER}
popd


# 1. Updates cocos_files.json
generate_cocosfiles_json

echo
echo cocos_files.json was generated successfully
echo

echo
echo Using "'$COMMITTAG'" in the commit messages
echo

ELAPSEDSECS=`date +%s`
echo Using "$ELAPSEDSECS" in the branch names for pseudo-uniqueness


# 2. Check if there are any files that are different from the index

pushd "$PROJECT_ROOT"

# Run status to record the output in the log
git status

echo
echo Comparing with origin HEAD ...
echo

git fetch origin ${FETCH_REMOTE_BRANCH}

# Don't exit on non-zero return value
set +e
git diff FETCH_HEAD --stat --exit-code ${COMMIT_PATH}

DIFF_RETVAL=$?
if [ $DIFF_RETVAL -eq 0 ]
then
    echo
    echo "No differences in cocos_files.json"
    echo "Exiting with success."
    echo
    exit 0
else
    echo
    echo "Generated files differ from HEAD. Continuing."
    echo
fi

# Exit on error
set -e

popd

COCOS_BRANCH=update_cocosfiles_"$ELAPSEDSECS"

pushd "${DIR}"

cd "${PROJECT_ROOT}"
git add templates/cocos2dx_files.json
git checkout -b "$COCOS_BRANCH"
git commit -m "$COMMITTAG"
#Set remotes
# should not add remote twice
upstream_cnt=$(git remote get-url upstream 2>/dev/null | wc -l)
if [ $upstream_cnt -eq 0 ]
  then
  git remote add upstream https://${GH_USER}:${GH_PASSWORD}@github.com/${GH_USER}/cocos2d-x-lite.git 2> /dev/null > /dev/null
fi

git fetch upstream --no-recurse-submodules

echo "Pushing to Robot's repo ..."
# print log
git push -fq upstream "$COCOS_BRANCH" 

# 5. 
echo "Sending Pull Request to base repo ..."
curl --user "${GH_USER}:${GH_PASSWORD}" --request POST --data "{ \"title\": \"$COMMITTAG\", \"body\": \"\", \"head\": \"${GH_USER}:${COCOS_BRANCH}\", \"base\": \"${TRAVIS_BRANCH}\"}" "${PUSH_REPO}" 2> /dev/null > /dev/null

popd
