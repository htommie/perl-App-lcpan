package App::lcpan::Cmd::script2dist;

# DATE
# VERSION

use 5.010;
use strict;
use warnings;

require App::lcpan;

our %SPEC;

$SPEC{'handle_cmd'} = {
    v => 1.1,
    summary => 'Get distribution name of a script',
    args => {
        %App::lcpan::common_args,
        %App::lcpan::scripts_args,
    },
};
sub handle_cmd {
    my %args = @_;

    my $state = App::lcpan::_init(\%args, 'ro');
    my $dbh = $state->{dbh};

    my $scripts = $args{scripts};

    my $scripts_s = join(",", map {$dbh->quote($_)} @$scripts);

    my $sth = $dbh->prepare("
SELECT
  script.name script,
  dist.name dist
FROM script
LEFT JOIN file ON script.file_id=file.id
LEFT JOIN dist ON file.id=dist.file_id
WHERE script.name IN ($scripts_s)");

    my $res;
    if (@$scripts == 1) {
        $sth->execute;
        (undef, $res) = $sth->fetchrow_array;
    } else {
        $sth->execute;
        $res = {};
        while (my $row = $sth->fetchrow_hashref) {
            $res->{$row->{script}} = $row->{dist};
        }
    }
    [200, "OK", $res];
}

1;
# ABSTRACT:
