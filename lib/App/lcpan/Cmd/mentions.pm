package App::lcpan::Cmd::mentions;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010;
use strict;
use warnings;
use Log::ger;

require App::lcpan;

our %SPEC;

$SPEC{'handle_cmd'} = {
    v => 1.1,
    summary => 'List mentions',
    description => <<'_',

This subcommand lists mentions (references to modules/scripts in POD files
inside releases).

Only mentions to modules/scripts in another release are indexed (i.e. mentions
to modules/scripts in the same dist/release are not indexed). Only mentions to
known scripts are indexed, but mentions to unknown modules are also indexed.

_
    args => {
        %App::lcpan::common_args,
        type => {
            summary => 'Filter by type of things being mentioned',
            schema => ['str*', in=>['any', 'script', 'module', 'unknown-module', 'known-module']],
            default => 'any',
            tags => ['category:filtering'],
        },

        mentioned_modules => {
            'x.name.is_plural' => 1,
            summary => 'Filter by module name(s) being mentioned',
            schema => ['array*', of=>'str*', min_len=>1],
            element_completion => \&App::lcpan::_complete_mod,
            tags => ['category:filtering'],
        },
        mentioned_scripts => {
            'x.name.is_plural' => 1,
            summary => 'Filter by script name(s) being mentioned',
            schema => ['array*', of=>'str*', min_len=>1],
            element_completion => \&App::lcpan::_complete_script,
            tags => ['category:filtering'],
        },
        mentioned_authors => {
            'x.name.is_plural' => 1,
            summary => 'Filter by author(s) of module/script being mentioned',
            schema => ['array*', of=>'str*', min_len=>1],
            tags => ['category:filtering'],
            completion => \&App::lcpan::_complete_cpanid,
        },

        mentioner_modules => {
            'x.name.is_plural' => 1,
            summary => 'Filter by module(s) that do the mentioning',
            schema => ['array*', of=>'str*', min_len=>1],
            element_completion => \&App::lcpan::_complete_mod,
            tags => ['category:filtering'],
        },
        mentioner_scripts => {
            'x.name.is_plural' => 1,
            summary => 'Filter by script(s) that do the mentioning',
            schema => ['array*', of=>'str*', min_len=>1],
            element_completion => \&App::lcpan::_complete_script,
            tags => ['category:filtering'],
        },
        mentioner_authors => {
            'x.name.is_plural' => 1,
            summary => 'Filter by author(s) of POD that does the mentioning',
            schema => ['array*', of=>'str*', min_len=>1],
            tags => ['category:filtering'],
            completion => \&App::lcpan::_complete_cpanid,
        },
        mentioner_authors_arent => {
            'x.name.is_plural' => 1,
            'x.name.singular' => 'mentioner_author_isnt',
            schema => ['array*', of=>'str*'],
            tags => ['category:filtering'],
            element_completion => \&App::lcpan::_complete_cpanid,
        },
        #%App::lcpan::fauthor_args,
        %App::lcpan::fctime_args,
        %App::lcpan::fmtime_args,
        %App::lcpan::fctime_or_mtime_args,
    },
};
sub handle_cmd {
    my %args = @_;

    my $state = App::lcpan::_init(\%args, 'ro');
    my $dbh = $state->{dbh};

    my $type = $args{type} // 'any';

    my $mentioned_modules = $args{mentioned_modules} // [];
    my $mentioned_scripts = $args{mentioned_scripts} // [];
    my $mentioned_authors = $args{mentioned_authors} // [];

    my $mentioner_modules = $args{mentioner_modules} // [];
    my $mentioner_scripts = $args{mentioner_scripts} // [];
    my $mentioner_authors = $args{mentioner_authors} // [];
    my $mentioner_authors_arent = $args{mentioner_authors_arent} // [];

    my @extra_join;
    my @bind;
    my @where;
    #my @having;

    App::lcpan::_set_since(\%args, $dbh);
    App::lcpan::_add_since_where_clause(\%args, \@where, "mention");

    if ($type eq 'script') {
        push @where, "mention.script_name IS NOT NULL";
    } elsif ($type eq 'module') {
        push @where, "(mention.module_id IS NOT NULL OR mention.module_name IS NOT NULL)";
    } elsif ($type eq 'known-module') {
        push @where, "mention.module_id IS NOT NULL";
    } elsif ($type eq 'unknown-module') {
        push @where, "mention.module_name IS NOT NULL";
    }

    if (@$mentioned_modules) {
        my $mods_s = join(",", map { $dbh->quote($_) } @$mentioned_modules);
        if ($type eq 'known-module') {
            push @where, "m1.name IN ($mods_s)";
        } elsif ($type eq 'unknown-module') {
            push @where, "mention.module_name IN ($mods_s)";
        } else {
            push @where, "(m1.name IN ($mods_s) OR mention.module_name IN ($mods_s))";
        }
    }

    if (@$mentioned_scripts) {
        my $scripts_s = join(",", map { $dbh->quote($_) } @$mentioned_scripts);
        push @where, "mention.script_name IN ($scripts_s)";
    }

    if (@$mentioned_authors) {
        my $authors_s = join(",", map { $dbh->quote(uc $_) } @$mentioned_authors);
        push @where, "(module_author IN ($authors_s) OR script_author IN ($authors_s))";
    }

    if (@$mentioner_modules) {
        my $mods_s = join(",", map { $dbh->quote($_) } @$mentioner_modules);
        push @where, "content.package IN ($mods_s)";
    }

    if (@$mentioner_scripts) {
        my $scripts_s = join(",", map { $dbh->quote($_) } @$mentioner_scripts);
        push @extra_join, "LEFT JOIN script s2 ON content.id=s2.content_id -- mentioner script";
        push @where, "s2.name IN ($scripts_s)";
    }

    if (@$mentioner_authors) {
        my $authors_s = join(",", map { $dbh->quote(uc $_) } @$mentioner_authors);
        push @where, "mentioner_author IN ($authors_s)";
    }

    if (@$mentioner_authors_arent) {
        my $authors_s = join(",", map { $dbh->quote(uc $_) } @$mentioner_authors_arent);
        push @where, "mentioner_author NOT IN ($authors_s)";
    }

    my $sql = "SELECT
  file.name release,
  content.path content_path,
  CASE WHEN m1.name IS NOT NULL THEN m1.name ELSE mention.module_name END AS module,
  m1.cpanid module_author,
  mention.script_name script,
  s1.cpanid script_author,
  file.cpanid mentioner_author
FROM mention
LEFT JOIN file ON file.id=mention.source_file_id
LEFT JOIN content ON content.id=mention.source_content_id
LEFT JOIN module m1 ON mention.module_id=m1.id -- mentioned script
LEFT JOIN script s1 ON mention.script_name=s1.name -- mentioned script
".
    (@extra_join ? join("", map {"$_\n"} @extra_join) : "").
    (@where ? "\nWHERE ".join(" AND ", @where) : "");#.
    #(@having ? "\nHAVING ".join(" AND ", @having) : "");

    my @res;
    my $sth = $dbh->prepare($sql);
    $sth->execute(@bind);
    while (my $row = $sth->fetchrow_hashref) {
        if (@$mentioned_modules || $type =~ /module/) {
            delete $row->{script};
            delete $row->{script_author};
        }
        if (@$mentioned_scripts || $type eq 'script') {
            delete $row->{module};
            delete $row->{module_author};
        }
        push @res, $row;
    }
    my $resmeta = {};
    $resmeta->{'table.fields'} = [qw/module module_author script script_author release mentioner_author content_path/];

    if (@$mentioned_modules || $type =~ /module/) {
        $resmeta->{'table.fields'} =
            [grep {$_ ne 'script' && $_ ne 'script_author'} @{$resmeta->{'table.fields'}}];
    }
    if (@$mentioned_scripts || $type eq 'script') {
        $resmeta->{'table.fields'} =
            [grep {$_ ne 'module' && $_ ne 'module_author'} @{$resmeta->{'table.fields'}}];
    }

    [200, "OK", \@res, $resmeta];
}

1;
# ABSTRACT:
