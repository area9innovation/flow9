pushd
cd %~dp0
call code --install-extension flow.vsix --force
popd
timeout 3