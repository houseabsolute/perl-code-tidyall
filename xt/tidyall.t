#!/usr/bin/perl
use lib 't/lib';
use Test::Code::TidyAll;
use Test::More;

plan skip_all => q{This test relies on Jon Swartz's perltidyrc settings};

tidyall_ok();

done_testing;
