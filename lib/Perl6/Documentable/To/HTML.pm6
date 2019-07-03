use v6.c;

use Perl6::Utils;
use Pod::To::HTML;
use Perl6::Documentable::Registry;

unit class Perl6::Documentable::To::HTML:ver<0.0.1>;

=begin pod

=head1 NAME

Perl6::Documentable::To::HTML

=head1 SYNOPSIS

=begin code :lang<perl6>

use Perl6::Documentable::To::HTML;

=end code

=head1 DESCRIPTION

Perl6::Documentable::To::HTML takes a Perl6::Documentable::Registry object and generate a full set of HTML files.

=head1 AUTHOR

Antonio <antoniogamiz10@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright 2019 Perl6 Team

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod

#| hardcoded menu
has @.menu;

#| head template
has $.head-template-path;
#| header template
has $.header-template-path;
#| footer template
has $.footer-template-path;

submethod BUILD() {
    # hardcoded menu (TODO => generate it automatically)
    @!menu = ('language', ''        ) => (),
             ('type'    , 'Types'   ) => <basic composite domain-specific exceptions>,
             ('routine' , 'Routines') => <sub method term operator trait submethod  >,
             ('programs', ''        ) => (),
             ('https://webchat.freenode.net/?channels=#perl6', 'Chat with us') => (); 

    # templates
    $!head-template-path   = %?RESOURCES ?? %?RESOURCES<template/head.html>   !! "template/head.html";
    $!header-template-path = %?RESOURCES ?? %?RESOURCES<template/header.html> !! "template/header.html";
    $!footer-template-path = %?RESOURCES ?? %?RESOURCES<template/footer.html> !! "template/footer.html";
}

#| Return the HTML header for every page
method header-html($current-selection, $pod-path) {
    state $header = slurp $!header-template-path;
    my $menu-items = [~]
        q[<div class="menu-items dark-green"><a class='menu-item darker-green' href='https://perl6.org'><strong>Perl&nbsp;6 homepage</strong></a> ],
        @!menu>>.key.map(-> ($dir, $name) {qq[
            <a class="menu-item {$dir eq $current-selection ?? "selected darker-green" !! ""}"
                href="{ $dir ~~ /https/ ?? $dir !! "/$dir.html" }">
                { $name || $dir.wordcase }
            </a>
        ]}), 
        q[</div>];

    my $sub-menu-items = '';
    state %sub-menus = @!menu>>.key>>[0] Z=> @!menu>>.value;
    if %sub-menus{$current-selection} -> $_ {
        $sub-menu-items = [~]
            q[<div class="menu-items darker-green">],
            qq[<a class="menu-item" href="/$current-selection.html">All</a>],
            .map({qq[
                <a class="menu-item" href="/$current-selection\-$_.html">
                    {.wordcase}
                </a>
            ]}),
            q[</div>];
    }

    my $edit-url = "";
    if defined $pod-path {
      $edit-url = qq[
      <div align="right">
        <button title="Edit this page"  class="pencil" onclick="location='https://github.com/perl6/doc/edit/master/doc/$pod-path'">
        {svg-for-file("html/images/pencil.svg")}
        </button>
      </div>]
    }

    $header.subst('MENU', $menu-items ~ $sub-menu-items)
            .subst('EDITURL', $edit-url)
            .subst: 'CONTENT_CLASS',
                'content_' ~ ($pod-path
                    ??  $pod-path.subst(/\.pod6$/, '').subst(/\W/, '_', :g)
                    !! 'fragment');
}

#| Return the footer HTML for every page
method footer-html($pod-path) is export {
    my $footer = slurp $!footer-template-path;
    $footer.subst-mutate(/DATETIME/, ~DateTime.now.utc.truncated-to('seconds'));
    my $pod-url;
    my $edit-url;
    my $gh-link = q[<a href='https://github.com/perl6/doc'>perl6/doc on GitHub</a>];
    if not defined $pod-path {
        $pod-url = "the sources at $gh-link";
        $edit-url = ".";
    }
    else {
        $pod-url = "<a href='https://github.com/perl6/doc/blob/master/doc/$pod-path'>$pod-path\</a\> at $gh-link";
        $edit-url = " or <a href='https://github.com/perl6/doc/edit/master/doc/$pod-path'>edit this page\</a\>.";
    }
    $footer.subst-mutate(/SOURCEURL/, $pod-url);
    $footer.subst-mutate(/EDITURL/, $edit-url);
    state $source-commit = qx/git rev-parse --short HEAD/.chomp;
    $footer.subst-mutate(:g, /SOURCECOMMIT/, $source-commit);

    return $footer;
}

#| Main method to transform a Pod to HTML.
method p2h($pod, $selection = 'nothing selected', :$pod-path = Nil) {
    pod2html $pod,
        :url(&rewrite-url-logged),
        :$head,
        :header(header-html($selection, $pod-path)),
        :footer(footer-html($pod-path)),
        :default-title("Perl 6 Documentation"),
        :css-url(''), # disable Pod::To::HTML's default CSS
    ;
}

#| Main method, responsible of orchestrate
method setup() {
    my $registry = Perl6::Documentable::Registry.new;

    for <Language Programs Type Native> {
        $registry.process-pod-dir(:topdir("doc"), :dir($_));
    }
}