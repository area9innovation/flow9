pushd
cd %~dp0
call code --install-extension flow.vsix
popd
timeout 3