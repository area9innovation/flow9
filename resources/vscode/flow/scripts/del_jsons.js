const path = require('path')
const fs = require('fs')
const yaml = require('js-yaml')

let jsonPath = path.join(__dirname, 'syntaxes_yamls.json')
let yamlFileNames = JSON.parse(fs.readFileSync(jsonPath).toString())

yamlFileNames.forEach(fileName => {
	yamlFilePath = path.join(__dirname, '../syntaxes', fileName)
	jsonFilePath = yamlFilePath.replace('.yaml', '.json')

	if (fs.existsSync(jsonFilePath)) {
		fs.unlinkSync(jsonFilePath)
		console.log('Removed ' + jsonFilePath)
	}
})
