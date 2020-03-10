var sourceMap = require("source-map");
var fs = require("fs");

if (process.argv.length > 4) {
	var generatedFile = process.argv[2];
	var jsonFile = process.argv[3];
	var sourceMapFile = process.argv[4];
	// console.log(jsonFile)

	var content = Array.from(JSON.parse(fs.readFileSync(jsonFile)));
	// console.log(content)

	sourceMap.SourceMapConsumer.with(JSON.parse(fs.readFileSync(sourceMapFile)), null, (consumer) => {
		var map = new sourceMap.SourceMapGenerator({
			"file" : generatedFile
		});

		consumer.eachMapping((m) => {
			map.addMapping({
				"name" : m.name,
				"source" : m.source,
				"generated" : {
					"line" : m.generatedLine,
					"column" : m.generatedLine
				},
				"original" : {
					"line" : m.originalLine,
					"column" : m.originalColumn
				}
			});
		})

		for (const r in content) {
			// console.log(content[r]);
			map.addMapping(content[r]);
		}

		fs.writeFileSync(sourceMapFile, map.toString());
		fs.unlinkSync(jsonFile);
	});
}