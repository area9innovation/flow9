import * as typenames from "./TestNativeHost-types.d";

  export interface User {
	name: string;
	id: number;
  }
   
  class UserAccount {
	name: string;
	id: number;
   
	constructor(name: string, id: number) {
	  this.name = name;
	  this.id = id;
	}
  }
   
  const unknown_user : User = new UserAccount("UNKNOWN", -1);

  var users: User[] = [];

  export function getUser(name: string): User {
	const user = users.find((val, ind, arr) => { return val.name == name; } , users);
	if (user != undefined) {
		return user;
	} else {
		return unknown_user;
	}
  }
   
  export function delUser(name: string) {
	users = users.filter((val, ind, arr) => { return val.name != name; });
  }

  export function addUser(user : User): void {
	  users.push(user);
  }

  export function makeUser(name: string, id : number): User {
	return new UserAccount(name, id);
  }

  export function makeUser1(pair: typenames.Pair<string, number>): User {
	return new UserAccount(pair.first, pair.second);
  }

/*
  //Uncomment to see the errors while checking types with typescript:

  export function makeUser2(pair: typenames.Pair<string, number>): User {
	return new UserAccount(pair.aaa, pair.bbb);
  }

  export function makeUser3(pair: typenames.Pairss<string, number>): User {
	return new UserAccount(pair.first, pair.second);
 }
*/

  export function userName(user: User): string {
	return user.name;
  }

  export function userId(user: User): number {
	return user.id;
  }
