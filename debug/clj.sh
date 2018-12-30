#!/bin/bash
java -Xms128m -Xmx768m -classpath clojure-1.2.0.jar:clojure-contrib-1.2.0.jar:. clojure.main $@
