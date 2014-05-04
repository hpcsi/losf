#!/usr/bin/env perl

package LosF_test_utils;

sub test_binary_existence {
    my $binary = shift;
    my $basename = basename($binary);
    ok (-x "$binary", "$basename binary");
    return;
}

1;
