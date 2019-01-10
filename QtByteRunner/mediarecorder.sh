mkdir -p GeneratedFiles/
rm -rf GeneratedFiles/Gstreamer.framework/
cp -a /Library/Frameworks/Gstreamer.framework GeneratedFiles/

rm GeneratedFiles/GStreamer.framework/Headers GeneratedFiles/GStreamer.framework/Commands
rm GeneratedFiles/GStreamer.framework/Versions/Current/Commands
rm -r GeneratedFiles/GStreamer.framework/Versions/Current/bin/
rm -r GeneratedFiles/GStreamer.framework/Versions/Current/etc/
rm -r GeneratedFiles/GStreamer.framework/Versions/Current/share/

pip install osxrelocator
osxrelocator -r GeneratedFiles/GStreamer.framework/Versions/Current /Library/Frameworks/GStreamer.framework/ @executable_path/../Frameworks/GStreamer.framework/
ln -sf ../../../../ GeneratedFiles/GStreamer.framework/Versions/Current/libexec/Frameworks
