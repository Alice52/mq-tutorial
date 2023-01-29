#!/bin/bash

cd ..
# 安装 husky
npm install -g husky

# 安装 husky git hooks
npx husky install

# commitlint 安装配置
npm install -g @commitlint/cli @commitlint/config-conventional

echo "module.exports = {extends: ['@commitlint/config-conventional']}" > ../commitlint.config.js

npx husky add .husky/commit-msg 'npx --no-install commitlint --edit "$1"'
