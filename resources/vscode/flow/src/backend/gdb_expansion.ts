import { MINode } from "./mi_parse"

const resultRegex = /^([a-zA-Z_\-][a-zA-Z0-9_\-]*|\[\d+\])\s*=\s*/;
const structRegex = /^[a-zA-Z_\_][a-zA-Z0-9_\_]*\(/;
const variableRegex = /^[a-zA-Z_\-][a-zA-Z0-9_\-]*/;
const errorRegex = /^\<.+?\>/;
const nullpointerRegex = /^0x0+\b/;
const charRegex = /^(\d+) ['"]/;
const numberRegex = /^\d+/;
const pointerCombineChar = ".";

class Parser{
	value: string;
	stack: string[];
	variable: string;
	variableCreate: (arg: any) => number;
	extra: any;

	constructor (variableCreate: (arg: any) => number, 
		value: string, root: string = "", extra: any = undefined) {
		this.variableCreate = variableCreate;
		this.value = value;
		this.stack = [root];
		this.extra = extra;
	}

	parseCString() {
		this.value = this.value.trim();
		if (this.value[0] != '"' && this.value[0] != '\'')
			return "";
		let stringEnd = 1;
		let inString = true;
		let charStr = this.value[0];
		let remaining = this.value.substr(1);
		let escaped = false;
		while (inString) {
			if (escaped)
				escaped = false;
			else if (remaining[0] == '\\')
				escaped = true;
			else if (remaining[0] == charStr)
				inString = false;

			remaining = remaining.substr(1);
			stringEnd++;
		}
		let str = this.value.substr(0, stringEnd).trim();
		this.value = this.value.substr(stringEnd).trim();
		return str;
	}

	getNamespace(variable) {
		let namespace = "";
		let prefix = "";
		this.stack.push(variable);
		this.stack.forEach(name => {
			prefix = "";
			if (name != "") {
				if (name.startsWith("["))
					namespace = namespace + name;
				else {
					if (namespace) {
						while (name.startsWith("*")) {
							prefix += "*";
							name = name.substr(1);
						}
						namespace = namespace + pointerCombineChar + name;
					}
					else
						namespace = name;
				}
			}
		});
		this.stack.pop();
		return prefix + namespace;
	};

	parseTupleOrList() {
		this.value = this.value.trim();
		if (this.value[0] != '{')
			return undefined;
		this.value = this.value.substr(1).trim();
		if (this.value[0] == '}') {
			this.value = this.value.substr(1).trim();
			return [];
		}
		if (this.value.startsWith("...")) {
			this.value = this.value.substr(3).trim();
			if (this.value[0] == '}') {
				this.value = this.value.substr(1).trim();
				return <any>"<...>";
			}
		}
		let eqPos = this.value.indexOf("=");
		let newValPos1 = this.value.indexOf("{");
		let newValPos2 = this.value.indexOf(",");
		let newValPos = newValPos1;
		if (newValPos2 != -1 && newValPos2 < newValPos1)
			newValPos = newValPos2;
		if (newValPos != -1 && eqPos > newValPos || eqPos == -1) { // is this.value list
			let values = [];
			this.stack.push("[0]");
			let val = this.parseValue();
			this.stack.pop();
			values.push(this.createValue("[0]", val));
			let remaining = this.value;
			let i = 0;
			while (true) {
				this.stack.push("[" + (++i) + "]");
				if (!(val = this.parseCommaValue())) {
					this.stack.pop();
					break;
				}
				this.stack.pop();
				values.push(this.createValue("[" + i + "]", val));
			}
			this.value = this.value.substr(1).trim(); // }
			return values;
		}

		let result = this.parseResult(true);
		if (result) {
			let results = [];
			results.push(result);
			while (result = this.parseCommaResult(true))
				results.push(result);
			this.value = this.value.substr(1).trim(); // }
			return results;
		}

		return undefined;
	}

	parsePrimitive() {
		let primitive: any;
		let match;
		this.value = this.value.trim();
		if (this.value.length == 0)
			primitive = undefined;
		else if (this.value.startsWith("true")) {
			primitive = "true";
			this.value = this.value.substr(4).trim();
		}
		else if (this.value.startsWith("false")) {
			primitive = "false";
			this.value = this.value.substr(5).trim();
		}
		else if (match = nullpointerRegex.exec(this.value)) {
			primitive = "<nullptr>";
			this.value = this.value.substr(match[0].length).trim();
		}
		else if (match = charRegex.exec(this.value)) {
			primitive = match[1];
			this.value = this.value.substr(match[0].length - 1);
			primitive += " " + this.parseCString();
		}
		else if (match = numberRegex.exec(this.value)) {
			primitive = match[0];
			this.value = this.value.substr(match[0].length).trim();
		}
		else if (match = variableRegex.exec(this.value)) {
			primitive = match[0];
			this.value = this.value.substr(match[0].length).trim();
		}
		else if (match = errorRegex.exec(this.value)) {
			primitive = match[0];
			this.value = this.value.substr(match[0].length).trim();
		}
		else {
			primitive = this.value;
		}
		return primitive;
	};

	parseValue() {
		this.value = this.value.trim();
		if (this.value[0] == '"')
			return this.parseCString();
		else if (this.value[0] == '{')
			return this.parseTupleOrList();
		else
			return this.parsePrimitive();
	};

	parseResult(pushToStack: boolean = false) {
		this.value = this.value.trim();
		let variableMatch = resultRegex.exec(this.value);
		if (!variableMatch)
			return undefined;
		this.value = this.value.substr(variableMatch[0].length).trim();
		let name = this.variable = variableMatch[1];
		if (pushToStack)
			this.stack.push(this.variable);
		let val = this.parseValue();
		if (pushToStack)
			this.stack.pop();
		return this.createValue(name, val);
	};

	createValue(name, val) {
		let ref = 0;
		if (typeof val == "object") {
			ref = this.variableCreate(val);
			val = "Object";
		}
		if (typeof val == "string" && val.startsWith("*0x")) {
			ref = this.variableCreate(this.getNamespace("*" + name));
			val = "Object@" + val;
		}
		if (typeof val == "string" && val.startsWith("<...>")) {
			ref = this.variableCreate(this.getNamespace(name));
			val = "...";
		}
		return {
			name: name,
			value: val,
			variablesReference: ref
		};
	}

	parseCommaValue() {
		this.value = this.value.trim();
		if (this.value[0] != ',')
			return undefined;
		this.value = this.value.substr(1).trim();
		return this.parseValue();
	};

	parseCommaResult(pushToStack: boolean = false) {
		this.value = this.value.trim();
		if (this.value[0] != ',')
			return undefined;
		this.value = this.value.substr(1).trim();
		return this.parseResult(pushToStack);
	};
}

export function expandValue(variableCreate: (arg: any) => number, 
	value: string, root: string = "", extra: any = undefined): any {
	
	let parser = new Parser(variableCreate, value, root, extra);
	return parser.parseValue();
}