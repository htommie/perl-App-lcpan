package App::lcpan::Cmd::authors_by_rel_count;

use 5.010;
use strict;
use warnings;

require App::lcpan;

# AUTHORITY
# DATE
# DIST
# VERSION

our %SPEC;

$SPEC{'handle_cmd'} = {
    v => 1.1,
    summary => 'List authors ranked by number of releases',
    args => {
        %App::lcpan::common_args,
    },
};
sub handle_cmd {
    my %args = @_;

    my $state = App::lcpan::_init(\%args, 'ro');
    my $dbh = $state->{dbh};

    my $sql = "SELECT
  cpanid author,
  COUNT(*) AS rel_count,
  ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM file), 4) rel_count_pct
FROM file a
GROUP BY cpanid
ORDER BY rel_count DESC
";

    my @res;
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    while (my $row = $sth->fetchrow_hashref) {
        push @res, $row;
    }

    require Data::TableData::Rank;
    Data::TableData::Rank::add_rank_column_to_table(table => \@res, data_columns => ['rel_count']);

    my $resmeta = {};
    $resmeta->{'table.fields'} = [qw/rank author rel_count rel_count_pct/];
    [200, "OK", \@res, $resmeta];
}

1;
# ABSTRACT:
