pushd
cd %~dp0
call code --install-extension flow-formatter.vsix --force
popd
timeout 3