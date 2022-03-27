package App::lcpan::Cmd::mod2rel;

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
    summary => 'Get (latest) release name of a module',
    args => {
        %App::lcpan::common_args,
        %App::lcpan::mod_args,
        %App::lcpan::full_path_args,
        # all=>1
    },
};
sub handle_cmd {
    my %args = @_;

    my $state = App::lcpan::_init(\%args, 'ro');
    my $dbh = $state->{dbh};

    my $mod = $args{module};

    my $row = $dbh->selectrow_hashref("SELECT
  file.cpanid cpanid,
  file.name name
FROM module
LEFT JOIN file ON module.file_id=file.id
WHERE module.name=?
ORDER BY version_numified DESC
", {}, $mod);
    my $rel;
    if ($row) {
        if ($args{full_path}) {
            $rel = App::lcpan::_fullpath(
                $row->{name}, $state->{cpan}, $row->{cpanid});
        } else {
            $rel = App::lcpan::_relpath(
                $row->{name}, $row->{cpanid});
        }
    }
    [200, "OK", $rel];
}

1;
# ABSTRACT:
