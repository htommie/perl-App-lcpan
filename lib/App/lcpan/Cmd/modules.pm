package App::lcpan::Cmd::modules;

use 5.010;
use strict;
use warnings;

require App::lcpan;

# AUTHORITY
# DATE
# DIST
# VERSION

our %SPEC;

$SPEC{handle_cmd} = $App::lcpan::SPEC{modules};
*handle_cmd = \&App::lcpan::modules;

1;
# ABSTRACT:
