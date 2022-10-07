#!/usr/bin/perl
use lib::relative 'lib';
use TestFor::Code::TidyAll::Git ();
$ENV{LC_ALL} = 'C';
TestFor::Code::TidyAll::Git->runtests;
