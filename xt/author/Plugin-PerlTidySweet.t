#!/usr/bin/perl

use Test::More;

plan skip_all => 'This plugin requires Perl 5.10+'
    unless $] >= 5.010;

use lib 't/lib';
use TestFor::Code::TidyAll::Plugin::PerlTidySweet;
TestFor::Code::TidyAll::Plugin::PerlTidySweet->runtests;
