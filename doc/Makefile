run: css.html \
	development.html \
	faq.html \
	flow.html \
	form.html \
	index.html \
	lingo.html \
	linux.html \
	mac.html \
	runtimes.html \
	tropic.html \
	windows.html

%.html: %.markdown
	echo "<link rel=\"stylesheet\" type=\"text/css\" media=\"screen\" href=\"style.css?v1\" />" > $@
	markdown $< >> $@
