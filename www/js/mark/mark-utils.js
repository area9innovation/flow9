/*
	Utilities for mark.min.js
*/

function getMarkInstance(querySelectorField) {
	console.log('Getting Mark.js instance for selector:', querySelectorField);

	const rootElement = document.querySelector('.' + querySelectorField);
	if (!rootElement) {
		console.warn('Root element not found for selector:', querySelectorField);
		return null;
	}

	// TODO: Add a filter for textwidgets we'd like to ignore.
	const textWidgets = rootElement.querySelectorAll('.textWidget');
	return new Mark(textWidgets);
}

function performMark(keyword, querySelectorField) {
	// Util.getParameter("devtrace") == "1"
	console.log('Mark.js performMark');
	const markInstance = getMarkInstance(querySelectorField);
	if (!markInstance) return;

	const options = {};
	markInstance.unmark({
		done: function () {
			markInstance.mark(keyword, options);
		}
	});
}

function performUnMark(querySelectorField) {
	// Util.getParameter("devtrace") == "1"
	console.log('Mark.js performUnMark');
	const markInstance = getMarkInstance(querySelectorField);
	if (!markInstance) return;

	markInstance.unmark();
}