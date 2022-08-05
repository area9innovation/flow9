const path = require('path')
const fs = require('fs')
const yaml = require('js-yaml')

let jsonPath = path.join(__dirname, 'syntaxes_yamls.json')
let yamlFileNames = JSON.parse(fs.readFileSync(jsonPath).toString())

yamlFileNames.forEach(fileName => {
	yamlFilePath = path.join(__dirname, '../syntaxes', fileName)
	jsonFilePath = yamlFilePath.replace('.yaml', '.json')

	obj = yaml.load(fs.readFileSync(yamlFilePath, {encoding: 'utf-8'}))
	fs.writeFileSync(jsonFilePath, JSON.stringify(obj, null, 4))
	console.log('Generated ' + jsonFilePath)
})
