#!/usr/bin/perl

use strict;
use warnings;

open OUT, '>code.inc' or die;

for my $fn (<*.glsl>) {
    open IN, $fn or die;

    my $name = $fn;
    $name =~ s/\.glsl$//;
    $name =~ s/[.-]/_/g;

    print OUT "static const char *SHADER_${name}[] = {\n";
    while (<IN>) {
      my $noline = s/\\\n//gs;

      s/\\/\\\\/gs;
      s/\"/\\\"/gs;
      s/\r//gs;
      s/\n/\\n/gs;

      print OUT "  \"$_\"";
      print OUT ',' unless $noline;
      print OUT "\n";
    }
    print OUT "  NULL\n};\n\n";
    close IN;
}

close OUT;
