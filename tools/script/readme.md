Instead of counter := "0",  the more general idea seems to be to introduce

	(a ^= value)

which would define a at the top of the function, and otherwise
replace the occurence with a.

This is inspired by beef

/*
How to reduce counter to 1 line:
1. The program is a value, which we display.
2. Defining function-level state using :: (counter)
3. Default arguments (input)
4. Implicit lambdas (button)
5. Overloaded functions or implicit conversion of args to array (cols)
6. All state is behaviour, so we lift code to FRP as required
7. Short names for material constructs
8. New syntax for "next" and implicit "getValue"
*/

cols(input(counter := "0"), button("COUNT", counter := counter + 1))

/* 
How to reduce temperature:
1. Conversion of unsubscriber from bidirectional to material
2. Lambda for vars. Functions can define what args are lambdas
3. Implicit conversion from int to double
4. Conversion from string to MText
5. Conversion from variable to input? Then we could avoid "input"
*/
cols(
	bidirectionalLink(celsius, fahrenheit, c * 9 / 5 + 32, (f - 32) * (5 / 9)),
	input(celsius := "0"), " Celsius =",
	input(fahrenheit := "0"), " Fahrenheit"
)

/*
How to reduce flight:
1. Implicit conversion from date to string
2. error: Implicit conversion from string to pair to some
   or something like that
3. hide: construct
*/

lines(
	dropdown(flightType := 0, "Pick flight", ["one-way flight", "return flight"]),
	hide(startDate := formatString2date(strReplace(startDateText, ".", "-"), "%M%D%YYYY")),
	input(startDateText := getCurrentDate(), error(
		if (startDate == None()) "Invalid date"
		else if (invalidDates) "Start date has to before leave date"
		else ""
	)),
	hide(endDate := formatString2date(strReplace(endDateText, ".", "-"), "%M%D%YYYY")),
	input(endDateText := getCurrentDate(), 
		enabled(flightType == 1),
		error(if(endDate == None()) "Invalid date" else "")
	),
	hide(invalidDates := flightType == 1 && 
		eitherMap(startDate, \s : Date -> {
			eitherMap(endDate, \e : Date -> s > e, true)
		}, true)
	),
	button(
		"BOOK",
		confirmation(
			"Confirmation", "OK", "enter",
			"You have booked a "
			+ (if (flightType == 0) "one-way" else "return")
			+ " flight on " + startDateText
			+ (if (flightType == 1) " returning " + endDateText else "")
		),
		enabled(
			startDate != None() && endDate != None() && !invalidDates
		)
	)
)

Idea:

We could have a system which took this kind of code and produced flow.
