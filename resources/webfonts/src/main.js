var fontkit = require('fontkit');
var path = require('path');
var fs = require('fs');

function get_arabic_unicode_subset() {
	// Only plain letters with diacritics, no «TURNED» nor «SMALL» nor «SUPERSCRIPT/SUBSCRIPT» etc.
	// No diacritic modifiers, numbers.
	var ranges = [
		// Arabic
		[0x620, 0x64B], [0x66E, 0x670], [0x671, 0x674], [0x675, 0x6D4],
		[0x6D5, 0x6D6], [0x6EE, 0x6F0], [0x6FA, 0x6FD], [0x6FF, 0x700],

		// Arabic Supplement
		[0x750, 0x780],

		// Arabic Extended
		[0x8A0, 0x8AD], [0x8AE, 0x8B5], [0x8B6, 0x8BE],
	]
	
	var r = [];
	for (var rangeno=0; rangeno<ranges.length; ++rangeno)
		for (var ch=ranges[rangeno][0]; ch<ranges[rangeno][1]; ++ch)
			r.push([String.fromCharCode(ch), String.fromCharCode(ch)]);
	return r;
}

function get_arabic_ligature_subset() {
	return [["لآ", "ﻷ"], ["لأ", "ﻵ"], ["لإ", "ﻹ"], ["لا", "ﻻ"]];
}

function get_arabic_mapping() {
	return get_arabic_unicode_subset().concat(get_arabic_ligature_subset());
}

function get_4form_safe_letters() {
	// No lam letter hence it forms a ligature.
	// We expect these to be represented with a single glyph in any form.
	return "بتثجحخسشصضطظعغفقكمنهي";
}

function prettyJSON(obj) {
    return JSON.stringify(obj, function(k,v) {
        //Check if this is a leaf-object with no child Arrays or Objects:
        for(var p in v) {
            if(Array.isArray(v[p]) || (typeof v[p] == 'object')) {
                return v;
            }
        }

        return JSON.stringify(v);

        //Cleanup the escaped strings mess the above generated:
    }, '\t').replace(/\\/g, '')
        .replace(/\"\[/g, '[')
        .replace(/\]\"/g,']')
        .replace(/\"\{/g, '{')
        .replace(/\}\"/g,'}');
};

var myArgs = process.argv.slice(2);

var project_path = myArgs[0]; //"~/Job/Area9_Technologies_ApS/projects/lyceum/rhapsode"
var font_path = path.join(project_path, "www", "fonts");
var font_config_fn = path.join(project_path, "resources", "fontconfig.json");
var font_css_fn = path.join(project_path, "www", "fonts", "fonts.css");
var fonts = [];

var font_css = null;

// Assuming all text files aren't too big, so loading whole files.

fs.readFileSync(font_css_fn, 'utf-8').split(/\r?\n/).forEach(function(line) {
	var linetrim = line.trim();
	var linetrimsplit = linetrim.split(/\s+/);
	if (linetrimsplit.length == 2 && linetrimsplit[0] == '@font-face' && linetrimsplit[1] == '{') {
		font_css = {};
	} else if (linetrim == '}') {
		var urls = font_css.src.match(/url\([\'\"][A-Za-z0-9\-\_\?\#\.]+[\'\"]\)/);
		var src = [];
		for (var i=0; i<urls.length; ++i) {
			if (!urls[i].includes('#iefix')) src.push(urls[i].slice(5, urls[i].length-2));
		};
		fonts.push({
			'src': src, 'font_family': font_css['font-family'].slice(1, -2)
		});
	} else if (font_css !== null) {
		var splitpos = linetrim.indexOf(' ');
		var key, value;
		if (splitpos >= 0) {
			key = linetrim.substr(0, splitpos-1).trim();
			value = linetrim.substr(splitpos+1).trim();
		} else {
			value = linetrim;
		}
		if (font_css[key] != null)
			font_css[key] += ' '+value;
		else
			font_css[key] = value;
	}
});

var font_config = JSON.parse(fs.readFileSync(font_config_fn))
font_config['webfontconfig']['custom']['metrics'] = {};

var safe_letters = get_4form_safe_letters();
var unis = get_arabic_mapping();
for (var fonti=0; fonti<fonts.length; ++fonti) {
	var font = fonts[fonti];
	var adwidths = {};
	for (var fontsrci=0; fontsrci<font.src.length; ++fontsrci) {
		console.log("Parsing "+font.src[fontsrci]);
		try {
			var fontobj = fontkit.openSync(path.join(font_path, font.src[fontsrci]));
			for (var safe_letteri=0; safe_letteri<safe_letters.length; ++safe_letteri) {
				var safe_letter = safe_letters.substr(safe_letteri, 1);
				for (unii=0; unii<unis.length; ++unii) {
					var uni = unis[unii];
					var tests = [
						[" "+uni[0]+" ", 1, -1],                 // Isolated
						[safe_letter+uni[0]+" ", 1, -1],         // Final
						[" "+uni[0]+safe_letter, 1, -1],         // Initial
						[safe_letter+uni[0]+safe_letter, 1, -1]  // Medial
					]
					var adwidth = []
					for (var testi=0; testi<4; ++testi) {
						var test = tests[testi];
						var glyphs = fontobj.layout(test[0]).glyphs;
						proj = [];
						for (var glyphi=0; glyphi<glyphs.length; ++glyphi) {
							// For a reason, there are sometimes zero width glyphs with no codepoints in the run.
							if (glyphs[glyphi].codePoints.length) {
								proj.push(glyphs[glyphi]._metrics.advanceWidth)
							}
						}
						if (test[2]<=0) test[2] += proj.length;
						proj = proj.slice(test[1], test[2]);
						if (proj.length != 1 && proj.length != test[2]-test[1]) {
							console.log("Unexpected glyphs count.");
							process.exit(1);
						}
						if (proj.length != test[2]-test[1]) {
							while(proj.length < test[2]-test[1]) {
								proj.push(proj[0]/(test[2]-test[1]));
							}
							proj[0] = proj[1];
						}
						adwidth.push(proj);
					}
					oldaw = adwidths[uni[1].charCodeAt(0)];
					var key = /*uni[1].charCodeAt(0)*/ uni[0];
					if (oldaw!=null) {
						if (JSON.stringify(oldaw) != JSON.stringify(adwidths[key])) {
							console.log("Metric calculated differently.");
							process.exit(1);
						}
					} else {
						adwidths[key] = adwidth;
						//console.log(key, adwidth, tests);
					}
				}
			}
		} catch (exc) {
			console.log(exc.toString());
			continue;
		}
	}
	if (JSON.stringify(adwidths) != '{}') {
		font_config['webfontconfig']['custom']['metrics'][font.font_family] = {"advanceWidth": adwidths}
	}
}
fs.writeFileSync(font_config_fn, JSON.stringify(font_config,undefined,'\t'));
