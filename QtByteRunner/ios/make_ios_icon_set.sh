mkdir Application.appiconset

cp iconsetcontent.json Application.appiconset/Contents.json

sips -Z 20 $1 --out Application.appiconset/default_20@1x.png
sips -Z 40 $1 --out Application.appiconset/default_20@2x.png
sips -Z 60 $1 --out Application.appiconset/default_20@3x.png

sips -Z 29 $1 --out Application.appiconset/default_29@1x.png
sips -Z 58 $1 --out Application.appiconset/default_29@2x.png
sips -Z 87 $1 --out Application.appiconset/default_29@3x.png

sips -Z 40 $1 --out Application.appiconset/default_40@1x.png
sips -Z 80 $1 --out Application.appiconset/default_40@2x.png
sips -Z 120 $1 --out Application.appiconset/default_40@3x.png

sips -Z 57 $1 --out Application.appiconset/default_57@1x.png
sips -Z 114 $1 --out Application.appiconset/default_57@2x.png

sips -Z 120 $1 --out Application.appiconset/default_60@2x.png
sips -Z 180 $1 --out Application.appiconset/default_60@3x.png

sips -Z 72 $1 --out Application.appiconset/default_72@1x.png
sips -Z 144 $1 --out Application.appiconset/default_72@2x.png

sips -Z 76 $1 --out Application.appiconset/default_76@1x.png
sips -Z 152 $1 --out Application.appiconset/default_76@2x.png

sips -Z 167 $1 --out Application.appiconset/default_83.5@2x.png

sips -Z 50 $1 --out Application.appiconset/default_50@1x.png
sips -Z 100 $1 --out Application.appiconset/default_50@2x.png

sips -Z 1024 $1 --out Application.appiconset/ItunesArtwork@2x.png
