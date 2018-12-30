mkdir Application.launchimage

cp launchimagecontent.json Application.launchimage/Contents.json

sips -p 2436 1125 $1 --out Application.launchimage/Default1125x2436.png
sips -p 1125 2436 $1 --out Application.launchimage/Default2436x1125.png

sips -p 2208 1242 $1 --out Application.launchimage/Default1242x2208.png
sips -p 1242 2208 $1 --out Application.launchimage/Default2208x1242.png

sips -p 2668 1500 $1 --out Application.launchimage/Default750x1334.png
sips -z 1334 750 Application.launchimage/Default750x1334.png


sips -p 2048 1536 $1 --out Application.launchimage/Default768x1024.png
sips -z 1024 768 Application.launchimage/Default768x1024.png
sips -p 1536 2048 $1 --out Application.launchimage/Default1024x768.png
sips -z 768 1024 Application.launchimage/Default1024x768.png

sips -p 2048 1536 $1 --out Application.launchimage/Default1536x2048.png
sips -p 1536 2048 $1 --out Application.launchimage/Default2048x1536.png

sips -p 1728 1152 $1 --out Application.launchimage/Default320x480.png
sips -z 480 320 Application.launchimage/Default320x480.png

sips -p 1728 1152 $1 --out Application.launchimage/Default640x960.png
sips -z 960 640 Application.launchimage/Default640x960.png

sips -p 2045 1152 $1 --out Application.launchimage/Default640x1136.png
sips -z 1136 640 Application.launchimage/Default640x1136.png

sips -p 1080 1920 $1 --out Application.launchimage/Default1920x1080.png
