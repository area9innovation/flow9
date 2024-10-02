This doc is created to bring order and make things deterministic about fonts, because what we have now is a mess and nobody has complete vision about.

Font transformation pipeline (incomplete)
-----------------------------------------

… → getMappedFont → fontName2fontFace → fontFace2familiesString


How to update Material icons
-----------------------------------------

1. Update list of the icons
	1.1. Go to `flow9/tools/material_icons`
	1.2. Call `flowcpp extract_icons.flow`
	1.3. Open `merge_icons.flow`
	1.4. Copy the content of `icons_created.txt` to `createdIcons` array
	1.5. Copy two parts of the `list` from `material_icons_list.flow` (https://github.com/area9innovation/flow9/blob/master/lib/material/internal/material_icons_list.flow#L41 and https://github.com/area9innovation/flow9/blob/master/lib/material/internal/material_icons_list.flow#L1818) to `existingIcons` array
	1.6. Call `flowcpp merge_icons.flow`
	1.7. Copy the content of `icons_merged.txt` back to `material_icons_list.flow`, splitting it in half
	1.8. Notify colleagues that keep their own copy of font locally or in the project. (GroveX, Rodion Safonov, etc.)

2. Update dfont for flowcpp
	2.1. Go to https://github.com/google/material-design-icons/tree/master/font
	2.2. Download `MaterialIcons-Regular.ttf`
	2.3. Go to `flow9/platforms/qt/bin/fontconvertor`
	2.4. Move `MaterialIcons-Regular.ttf` to current directory
	2.5. Call `FlowFontConvertor.exe -x MaterialIcons-Regular.ttf`
	2.6. Cut generated `*.xmf` and `index.dat` to `flow9/resources/dfont/MaterialIcons`
	2.7. Download .otf for other 4 types
	2.8. Convert drom .otf to .ttf, using any font convertor (for example, https://cloudconvert.com/ttf-to-woff2)
	2.9. Repeat 2.3 - 2.6, changing font name
	2.10. Go to https://github.com/google/material-design-icons/tree/master/variablefont
	2.11. Download .ttf files for 3 types of Material Symbols
	2.12. Repeat 2.3 - 2.6, changing font name

Note : Do not forget to update MaterialIcons in dependent projects as well.