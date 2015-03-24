package App::lcpan::Cmd::authors_by_mod_count;

# XXX fix query (too slow)

# DATE
# VERSION

use 5.010;
use strict;
use warnings;

require App::lcpan;

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
    summary => "'authors-by-mod-count' command",
};

$SPEC{'handle_cmd'} = {
    v => 1.1,
    summary => 'List authors ranked by number of modules',
    args => {
        %App::lcpan::common_args,
    },
    result_naked=>1,
};
sub handle_cmd {
    my %args = @_;

    App::lcpan::_set_args_default(\%args);
    my $cpan = $args{cpan};
    my $index_name = $args{index_name};

    my $dbh = App::lcpan::_connect_db('ro', $cpan, $index_name);

    my $sql = "SELECT
  cpanid id,
  (SELECT COUNT(*) FROM module WHERE file_id IN (SELECT id FROM file WHERE cpanid=a.cpanid)) AS mod_count
FROM author a
ORDER BY mod_count DESC
";

    my @res;
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    while (my $row = $sth->fetchrow_hashref) {
        push @res, $row;
    }
    \@res;
}

1;
# ABSTRACT: