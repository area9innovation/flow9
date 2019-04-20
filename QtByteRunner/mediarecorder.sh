pwd
cd "$(dirname "$0")"
pwd
mkdir -p GeneratedFiles/GStreamer.framework
rm -rf GeneratedFiles/GStreamer.framework/
cp -a /Library/Frameworks/GStreamer.framework GeneratedFiles/GStreamer.framework

rm GeneratedFiles/GStreamer.framework/Headers GeneratedFiles/GStreamer.framework/Commands
rm GeneratedFiles/GStreamer.framework/Versions/Current/Commands
rm -r GeneratedFiles/GStreamer.framework/Versions/Current/bin/
rm -r GeneratedFiles/GStreamer.framework/Versions/Current/etc/
rm -r GeneratedFiles/GStreamer.framework/Versions/Current/share/

/usr/local/bin/pip install osxrelocator
/usr/local/bin/osxrelocator -r GeneratedFiles/GStreamer.framework/Versions/Current /Library/Frameworks/GStreamer.framework/ @executable_path/../Frameworks/GStreamer.framework/
ln -sf ../../../../ GeneratedFiles/GStreamer.framework/Versions/Current/libexec/Frameworks
