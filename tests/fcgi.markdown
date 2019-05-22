FastCGI for Flow
================

This is a test for FastCGI implementation for Flow language.

To run FastCGI server, there is a native method `runFastCGIServer()`,
which is implemented in Java backend.

If you use in your code, you have to compile JAR file.
Please see [build-fcgi.sh](build-fcgi.sh)([build-fcgi.bat](build-fcgi.bat))

Next, you have to enable FastCGI in web server. It depends on server, of course.

In Apache2 you have to add something like this into config file:

```

<IfModule mod_fastcgi.c>
    Alias /ttt /Applications/MAMP/htdocs/app.sh
    Action ttt /ttt
    FastCgiExternalServer /Applications/MAMP/htdocs/app.sh -host 127.0.0.1:9000
</IfModule>

```

`/Application/MAMP/htdocs/` path must exist, according to (documentation)[https://github.com/FastCGI-Archives/mod_fastcgi/blob/master/CONFIG.md#FastCgiExternalServer],
but `app.sh` doesn't.

Apache will expect that FastCGI server is being started independently.

So, `java -jar fcgi.jar` does what we want.

Then, all request to http://127.0.0.1/ttt will be forwarded to newly created FastCGI server.
