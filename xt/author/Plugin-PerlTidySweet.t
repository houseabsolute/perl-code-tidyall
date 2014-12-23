#!/usr/bin/perl

use Test::More;

plan skip_all => 'This plugin requires Perl 5.10+'
    unless $] >= 5.010;

use lib 't/lib';
use Test::Code::TidyAll::Plugin::PerlTidySweet;
Test::Code::TidyAll::Plugin::PerlTidySweet->runtests;
