package App::lcpan::Cmd::rels;

use 5.010;
use strict;
use warnings;

use Function::Fallback::CoreOrPP qw(clone);

require App::lcpan;

# AUTHORITY
# DATE
# DIST
# VERSION

our %SPEC;

$SPEC{handle_cmd} = do {
    my $spec = clone($App::lcpan::SPEC{releases});
    $spec->{summary} = "Alias for 'releases'";
    $spec;
};
*handle_cmd = \&App::lcpan::releases;

1;
# ABSTRACT:
