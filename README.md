# NAME

Code::TidyAll - Engine for tidyall, your all-in-one code tidier and validator

# VERSION

version 0.60

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

# CONSTRUCTION

## Constructor methods

- new (%params)

    The regular constructor. Must pass at least _plugins_ and _root\_dir_.

- new\_with\_conf\_file ($conf\_file, %params)

    Takes a conf file path, followed optionally by a set of key/value parameters.
    Reads parameters out of the conf file and combines them with the passed
    parameters (the latter take precedence), and calls the regular constructor.

    If the conf file or params defines _tidyall\_class_, then that class is
    constructed instead of `Code::TidyAll`.

## Constructor parameters

- plugins

    Specify a hash of plugins, each of which is itself a hash of options. This is
    equivalent to what would be parsed out of the sections in the configuration
    file.

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
    @_` but [Test::Code::TidyAll](https://metacpan.org/pod/Test::Code::TidyAll) overrides this to use the `Test::Builder->diag` method.

# METHODS

- process\_paths (path, ...)

    Call ["process\_file"](#process_file) on each file; descend recursively into each directory if
    the `recursive` flag is on. Return a list of [Code::TidyAll::Result](https://metacpan.org/pod/Code::TidyAll::Result) objects,
    one for each file.

- process\_file (file)

    Process the _file_, meaning

    - Check the cache and return immediately if file has not changed
    - Apply appropriate matching plugins
    - Print success or failure result to STDOUT, depending on quiet/verbose settings
    - Write the cache if enabled
    - Return a [Code::TidyAll::Result](https://metacpan.org/pod/Code::TidyAll::Result) object

- process\_source (_source_, _path_)

    Like ["process\_file"](#process_file), but process the _source_ string instead of a file, and
    do not read from or write to the cache. You must still pass the relative
    _path_ from the root as the second argument, so that we know which plugins to
    apply. Return a [Code::TidyAll::Result](https://metacpan.org/pod/Code::TidyAll::Result) object.

- plugins\_for\_path (_path_)

    Given a relative _path_ from the root, return a list of
    [Code::TidyAll::Plugin](https://metacpan.org/pod/Code::TidyAll::Plugin) objects that apply to it, or an empty list if no
    plugins apply.

- find\_conf\_file (_conf\_names_, _start\_dir_)

    Class method. Start in the _start\_dir_ and work upwards, looking for one of
    the _conf\_names_. Return the pathname if found or throw an error if not found.

- find\_matched\_files

    Returns a list of sorted files that match at least one plugin in configuration.

# SUPPORT

Bugs may be submitted at
[https://github.com/houseabsolute/perl-code-tidyall/issues](https://github.com/houseabsolute/perl-code-tidyall/issues).

I am also usually active on IRC as 'autarch' on `irc://irc.perl.org`.

# SOURCE

The source code repository for Code-TidyAll can be found at
[https://github.com/houseabsolute/perl-code-tidyall](https://github.com/houseabsolute/perl-code-tidyall).

# AUTHORS

- Jonathan Swartz <swartz@pobox.com>
- Dave Rolsky <autarch@urth.org>

# CONTRIBUTORS

- Adam Herzog <adam@adamherzog.com>
- Andy Jack <andyjack@cpan.org>
- Finn Smith <finn@timeghost.net>
- George Hartzell <georgewh@gene.com>
- Graham Knop <haarg@haarg.org>
- Gregory Oschwald <goschwald@maxmind.com>
- Joe Crotty <joe.crotty@returnpath.net>
- Mark Fowler <mark@twoshortplanks.com>
- Mark Grimes <mgrimes@cpan.org>
- Martin Gruner <martin.gruner@otrs.com>
- Mohammad S Anwar <mohammad.anwar@yahoo.com>
- Olaf Alders <olaf@wundersolutions.com>
- Pedro Melo <melo@simplicidade.org>
- Ricardo Signes <rjbs@cpan.org>
- Sergey Romanov <sromanov-dev@yandex.ru>
- Shlomi Fish <shlomif@shlomifish.org>
- timgimyee <tim.gim.yee@gmail.com>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2011 - 2017 by Jonathan Swartz.

This is free software; you can redistribute it and/or modify it under the same
terms as the Perl 5 programming language system itself.

The full text of the license can be found in the `LICENSE` file included with
this distribution.
