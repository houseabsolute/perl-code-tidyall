# NAME

Code::TidyAll - Engine for tidyall, your all-in-one code tidier and validator

# VERSION

version 0.80

# SYNOPSIS

    use Code::TidyAll;

    my $ct = Code::TidyAll->new_from_conf_file(
        '/path/to/conf/file',
        ...
    );

    # or

    my $ct = Code::TidyAll->new(
        root_dir => '/path/to/root',
        plugins  => {
            perltidy => {
                select => 'lib/**/*.(pl|pm)',
                argv => '-noll -it=2',
            },
            ...
        }
    );

    # then...

    $ct->process_paths($file1, $file2);

# DESCRIPTION

This is the engine used by [tidyall](https://metacpan.org/pod/tidyall) - read that first to get an overview.

You can call this API from your own program instead of executing `tidyall`.

# METHODS

This class offers the following methods:

## Code::TidyAll->new(%params)

The regular constructor. Must pass at least _plugins_ and _root\_dir_.

## $tidyall->new\_from\_conf\_file( $conf\_file, %params )

Takes a conf file path, followed optionally by a set of key/value parameters.
Reads parameters out of the conf file and combines them with the passed
parameters (the latter take precedence), and calls the regular constructor.

If the conf file or params defines _tidyall\_class_, then that class is
constructed instead of `Code::TidyAll`.

### Constructor parameters

- plugins

    Specify a hash of plugins, each of which is itself a hash of options. This is
    equivalent to what would be parsed out of the sections in the configuration
    file.

- selected\_plugins

    An arrayref of plugins to be used. This overrides the `mode` parameter.

    This is really only useful if you're getting configuration from a config file
    and want to narrow the set of plugins to be run.

    Note that plugins will still only run on files which match their `select` and
    `ignore` configuration.

- cache\_model\_class

    The cache model class. Defaults to `Code::TidyAll::CacheModel`

- cache

    The cache instance (e.g. an instance of `Code::TidyAll::Cache` or a `CHI`
    instance.) An instance of `Code::TidyAll::Cache` is automatically instantiated
    by default.

- backup\_ttl
- check\_only

    If this is true, then we simply check that files pass validation steps and that
    tidying them does not change the file. Any changes from tidying are not
    actually written back to the file.

- no\_cleanup

    A boolean indicating if we should skip cleaning temporary files or not.
    Defaults to false.

- inc

    An arrayref of directories to prepend to `@INC`. This can be set via the
    command-line as `-I`, but you can also set it in a config file.

    This affects both loading and running plugins.

- data\_dir
- iterations
- mode
- no\_backups
- no\_cache
- output\_suffix
- quiet
- root\_dir
- ignore
- verbose

    These options are the same as the equivalent `tidyall` command-line options,
    replacing dashes with underscore (e.g. the `backup-ttl` option becomes
    `backup_ttl` here).

- msg\_outputter

    This is a subroutine reference that is called whenever a message needs to be
    printed in some way. The sub receives a `sprintf()` format string followed by
    one or more parameters. The default sub used simply calls `printf "$format\n",
    @_` but [Test::Code::TidyAll](https://metacpan.org/pod/Test%3A%3ACode%3A%3ATidyAll) overrides this to use the `Test::Builder->diag` method.

## $tidyall->process\_paths( $path, ... )

This method iterates through a list of paths, processing all the files it
finds. It will descend into subdirectories if `recursive` flag is true.
Returns a list of [Code::TidyAll::Result](https://metacpan.org/pod/Code%3A%3ATidyAll%3A%3AResult) objects, one for each file.

## $tidyall->process\_file( $file )

Process the one _file_, meaning:

- Check the cache and return immediately if file has not changed.
- Apply appropriate matching plugins.
- Print success or failure result to STDOUT, depending on quiet/verbose settings.
- Write to the cache if caching is enabled.
- Return a [Code::TidyAll::Result](https://metacpan.org/pod/Code%3A%3ATidyAll%3A%3AResult) object.

## $tidyall->process\_source( $source, $path )

Like `process_file`, but process the _source_ string instead of a file, and
does not read from or write to the cache. You must still pass the relative
_path_ from the root as the second argument, so that we know which plugins to
apply. Returns a [Code::TidyAll::Result](https://metacpan.org/pod/Code%3A%3ATidyAll%3A%3AResult) object.

## $tidyall->plugins\_for\_path($path)

Given a relative _path_ from the root, returns a list of
[Code::TidyAll::Plugin](https://metacpan.org/pod/Code%3A%3ATidyAll%3A%3APlugin) objects that apply to it, or an empty list if no
plugins apply.

## $tidyall->find\_matched\_files

Returns a list of sorted files that match at least one plugin in configuration.

## Code::TidyAll->find\_conf\_file( $conf\_names, $start\_dir )

Start in the _start\_dir_ and work upwards, looking for a file matching one of
the _conf\_names_. Returns the pathname if found or throw an error if not
found.

# SUPPORT

Bugs may be submitted at [https://github.com/houseabsolute/perl-code-tidyall/issues](https://github.com/houseabsolute/perl-code-tidyall/issues).

# SOURCE

The source code repository for Code-TidyAll can be found at [https://github.com/houseabsolute/perl-code-tidyall](https://github.com/houseabsolute/perl-code-tidyall).

# AUTHORS

- Jonathan Swartz <swartz@pobox.com>
- Dave Rolsky <autarch@urth.org>

# CONTRIBUTORS

- Adam Herzog <adam@adamherzog.com>
- Andy Jack <andyjack@cpan.org>
- Bernhard Schmalhofer <Bernhard.Schmalhofer@gmx.de>
- Finn Smith <finn@timeghost.net>
- George Hartzell <georgewh@gene.com>
- Graham Knop <haarg@haarg.org>
- Gregory Oschwald <goschwald@maxmind.com>
- Joe Crotty <joe.crotty@returnpath.net>
- Kenneth Ölwing <kenneth.olwing@skatteverket.se>
- Mark Fowler <mark@twoshortplanks.com>
- Mark Grimes <mgrimes@cpan.org>
- Martin Gruner <martin.gruner@otrs.com>
- Mohammad S Anwar <mohammad.anwar@yahoo.com>
- Nick Tonkin <ntonkin@bur-ntonkin-m1.corp.endurance.com>
- Olaf Alders <olaf@wundersolutions.com>
- Pedro Melo <melo@simplicidade.org>
- Ricardo Signes <rjbs@cpan.org>
- Sergey Romanov <sromanov-dev@yandex.ru>
- Shlomi Fish <shlomif@shlomifish.org>
- timgimyee <tim.gim.yee@gmail.com>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2011 - 2021 by Jonathan Swartz.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

The full text of the license can be found in the
`LICENSE` file included with this distribution.
