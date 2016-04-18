# NAME

Code::TidyAll - Engine for tidyall, your all-in-one code tidier and validator

# VERSION

version 0.46

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

bugs may be submitted through
[https://github.com/houseabsolute/perl-code-tidyall/issues](https://github.com/houseabsolute/perl-code-tidyall/issues).

I am also usually active on IRC as 'drolsky' on `irc://irc.perl.org`.

# DONATIONS

If you'd like to thank me for the work I've done on this module, please
consider making a "donation" to me via PayPal. I spend a lot of free time
creating free software, and would appreciate any support you'd care to offer.

Please note that **I am not suggesting that you must do this** in order for me
to continue working on this particular software. I will continue to do so,
inasmuch as I have in the past, for as long as it interests me.

Similarly, a donation made in this way will probably not make me work on this
software much more, unless I get so many donations that I can consider working
on free software full time (let's all have a chuckle at that together).

To donate, log into PayPal and send money to autarch@urth.org, or use the
button at [http://www.urth.org/~autarch/fs-donation.html](http://www.urth.org/~autarch/fs-donation.html).

# AUTHORS

- Jonathan Swartz &lt;swartz@pobox.com>
- Dave Rolsky &lt;autarch@urth.org>

# CONTRIBUTORS

- Andy Jack &lt;andyjack@cpan.org>
- Finn Smith &lt;finn@timeghost.net>
- George Hartzell &lt;georgewh@gene.com>
- Gregory Oschwald &lt;goschwald@maxmind.com>
- Joe Crotty &lt;joe.crotty@returnpath.net>
- Mark Fowler &lt;mark@twoshortplanks.com>
- Mark Grimes &lt;mgrimes@cpan.org>
- Martin Gruner &lt;martin.gruner@otrs.com>
- Mohammad S Anwar &lt;mohammad.anwar@yahoo.com>
- Olaf Alders &lt;olaf@wundersolutions.com>
- Pedro Melo &lt;melo@simplicidade.org>
- Ricardo Signes &lt;rjbs@cpan.org>
- Sergey Romanov &lt;sromanov-dev@yandex.ru>
- timgimyee &lt;tim.gim.yee@gmail.com>

# COPYRIGHT AND LICENCE

This software is copyright (c) 2011 - 2016 by Jonathan Swartz.

This is free software; you can redistribute it and/or modify it under the same
terms as the Perl 5 programming language system itself.
